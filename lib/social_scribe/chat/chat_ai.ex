defmodule SocialScribe.Chat.ChatAI do
  @moduledoc """
  AI chat processor that handles @mention-based CRM contact lookups
  and generates AI responses using Gemini.
  """

  alias SocialScribe.Accounts
  alias SocialScribe.Meetings
  alias SocialScribe.HubspotApiBehaviour, as: HubspotApi
  alias SocialScribe.SalesforceApiBehaviour, as: SalesforceApi
  alias SocialScribe.AIContentGeneratorApi

  require Logger

  @common_words ~w(I What Who Where When Why How Can Could Would Should Tell Show Find Get Check The This That And But For With About From Your My His Her Their Our Its Also Just Ask Has Have Had Been Being Will)

  @doc """
  Processes a user message: extracts @mentions, searches CRMs for contacts,
  fetches relevant meeting transcripts, builds context, and generates an AI response.

  Returns {:ok, %{content: String.t(), metadata: map()}} or {:error, reason}
  """
  def process_message(user_message, user_id, conversation_messages \\ []) do
    mentions = extract_mentions(user_message)
    credentials = get_user_crm_credentials(user_id)

    # Fetch contact data for all @mentions
    {contacts, crm_sources} = fetch_mentioned_contacts(mentions, credentials)

    # Fetch meetings where mentioned contacts participated
    {meeting_context, meeting_sources} = fetch_relevant_meetings(mentions, user_id)

    # Build the prompt with both CRM and meeting context
    messages = build_chat_messages(user_message, conversation_messages, contacts, meeting_context)

    case AIContentGeneratorApi.chat_completion(messages) do
      {:ok, response} ->
        {:ok,
         %{
           content: response,
           metadata: %{
             "sources" => crm_sources ++ meeting_sources,
             "mentions" => mentions
           }
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extracts @Name patterns from message text.
  Supports "@First Last" and "@First" patterns.
  Falls back to detecting capitalized names when no @mentions are found.
  """
  def extract_mentions(text) do
    at_mentions =
      ~r/@([A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)?)/
      |> Regex.scan(text)
      |> Enum.map(fn [_full, name] -> String.trim(name) end)
      |> Enum.uniq()

    if Enum.empty?(at_mentions) do
      extract_names_fallback(text)
    else
      at_mentions
    end
  end

  defp extract_names_fallback(text) do
    ~r/\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b/
    |> Regex.scan(text)
    |> Enum.map(fn [_full, name] -> String.trim(name) end)
    |> Enum.reject(fn name ->
      first_word = name |> String.split() |> List.first()
      first_word in @common_words
    end)
    |> Enum.uniq()
  end

  @doc """
  Gets all connected CRM credentials (HubSpot + Salesforce) for a user.
  """
  def get_user_crm_credentials(user_id) do
    hubspot = Accounts.get_user_hubspot_credential(user_id)
    salesforce = Accounts.get_user_salesforce_credential(user_id)

    []
    |> maybe_add_credential(hubspot, :hubspot)
    |> maybe_add_credential(salesforce, :salesforce)
  end

  defp maybe_add_credential(list, nil, _type), do: list
  defp maybe_add_credential(list, credential, type), do: [{type, credential} | list]

  @doc """
  For each @name, searches each connected CRM and returns matching contacts.
  Returns {contacts_map, sources_list}.
  """
  def fetch_mentioned_contacts(mentions, credentials) do
    results =
      for name <- mentions, {crm_type, credential} <- credentials do
        case search_crm(crm_type, credential, name) do
          {:ok, contacts} when contacts != [] ->
            source = %{
              "crm" => to_string(crm_type),
              "name" => name,
              "contacts_found" => length(contacts)
            }

            {contacts, source}

          _ ->
            {[], nil}
        end
      end

    contacts =
      results
      |> Enum.flat_map(fn {contacts, _} -> contacts end)
      |> Enum.uniq_by(& &1.email)

    sources =
      results
      |> Enum.map(fn {_, source} -> source end)
      |> Enum.reject(&is_nil/1)

    {contacts, sources}
  end

  @doc """
  Fetches meetings where any of the mentioned names appear as participants.
  Returns {meeting_context_string, meeting_sources_list}.
  """
  def fetch_relevant_meetings([], _user_id), do: {"", []}

  def fetch_relevant_meetings(mentions, user_id) do
    meetings = Meetings.list_user_meetings_by_user_id(user_id)

    matching_meetings =
      meetings
      |> Enum.filter(fn meeting ->
        Enum.any?(meeting.meeting_participants, fn participant ->
          Enum.any?(mentions, fn mention ->
            participant.name &&
              String.contains?(
                String.downcase(participant.name),
                String.downcase(mention)
              )
          end)
        end)
      end)
      |> Enum.take(5)

    meeting_context =
      matching_meetings
      |> Enum.map(fn meeting ->
        case Meetings.generate_prompt_for_meeting(meeting) do
          {:ok, prompt} -> prompt
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n---\n")

    meeting_sources =
      Enum.map(matching_meetings, fn meeting ->
        %{
          "type" => "meeting",
          "title" => meeting.title,
          "date" =>
            if(meeting.recorded_at, do: Date.to_string(DateTime.to_date(meeting.recorded_at))),
          "meeting_id" => meeting.id
        }
      end)

    {meeting_context, meeting_sources}
  end

  defp search_crm(:hubspot, credential, query) do
    HubspotApi.search_contacts(credential, query)
  end

  defp search_crm(:salesforce, credential, query) do
    SalesforceApi.search_contacts(credential, query)
  end

  defp build_chat_messages(user_message, conversation_history, contacts, meeting_context) do
    system_prompt = build_system_prompt(contacts, meeting_context)

    history =
      conversation_history
      |> Enum.map(fn msg ->
        %{role: msg.role, content: msg.content}
      end)

    [%{role: "system", content: system_prompt}] ++
      history ++
      [%{role: "user", content: user_message}]
  end

  defp build_system_prompt(contacts, meeting_context) do
    base = """
    You are an AI assistant for Social Scribe, a meeting transcription and CRM platform.
    You help users with questions about their CRM contacts and meeting data.
    Be helpful, concise, and accurate. If you don't have enough information to answer,
    say so clearly. If the user asks about a contact but no CRM data was found,
    suggest they try using @Name format (e.g., @John Smith) to look up a specific contact.
    """

    prompt =
      if Enum.any?(contacts) do
        contact_info =
          contacts
          |> Enum.map(&format_contact_for_prompt/1)
          |> Enum.join("\n\n")

        """
        #{base}

        The following CRM contact data is available for this conversation:

        #{contact_info}

        Use this data to answer the user's questions. Reference specific field values when relevant.
        """
      else
        base
      end

    if meeting_context != "" do
      """
      #{prompt}

      The following meeting transcript data is available:

      #{meeting_context}

      When answering, reference specific meeting dates and what participants said.
      """
    else
      prompt
    end
  end

  defp format_contact_for_prompt(contact) do
    fields =
      contact
      |> Map.drop([:id, :display_name])
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Enum.map(fn {k, v} -> "  #{k}: #{v}" end)
      |> Enum.join("\n")

    "Contact: #{contact[:display_name] || "Unknown"}\n#{fields}"
  end
end
