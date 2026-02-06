defmodule SocialScribe.Chat.ChatAI do
  @moduledoc """
  AI chat processor that handles @mention-based CRM contact lookups
  and generates AI responses using Gemini.
  """

  alias SocialScribe.Accounts
  alias SocialScribe.HubspotApiBehaviour, as: HubspotApi
  alias SocialScribe.SalesforceApiBehaviour, as: SalesforceApi
  alias SocialScribe.AIContentGeneratorApi

  require Logger

  @doc """
  Processes a user message: extracts @mentions, searches CRMs for contacts,
  builds context, and generates an AI response.

  Returns {:ok, %{content: String.t(), metadata: map()}} or {:error, reason}
  """
  def process_message(user_message, user_id, conversation_messages \\ []) do
    mentions = extract_mentions(user_message)
    credentials = get_user_crm_credentials(user_id)

    # Fetch contact data for all @mentions
    {contacts, sources} = fetch_mentioned_contacts(mentions, credentials)

    # Build the prompt
    messages = build_chat_messages(user_message, conversation_messages, contacts)

    case AIContentGeneratorApi.chat_completion(messages) do
      {:ok, response} ->
        {:ok,
         %{
           content: response,
           metadata: %{
             "sources" => sources,
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
  """
  def extract_mentions(text) do
    ~r/@([A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)?)/
    |> Regex.scan(text)
    |> Enum.map(fn [_full, name] -> String.trim(name) end)
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

  defp search_crm(:hubspot, credential, query) do
    HubspotApi.search_contacts(credential, query)
  end

  defp search_crm(:salesforce, credential, query) do
    SalesforceApi.search_contacts(credential, query)
  end

  defp build_chat_messages(user_message, conversation_history, contacts) do
    system_prompt = build_system_prompt(contacts)

    history =
      conversation_history
      |> Enum.map(fn msg ->
        %{role: msg.role, content: msg.content}
      end)

    [%{role: "system", content: system_prompt}] ++
      history ++
      [%{role: "user", content: user_message}]
  end

  defp build_system_prompt(contacts) do
    base = """
    You are an AI assistant for Social Scribe, a meeting transcription and CRM platform.
    You help users with questions about their CRM contacts and meeting data.
    Be helpful, concise, and accurate. If you don't have enough information to answer,
    say so clearly.
    """

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
