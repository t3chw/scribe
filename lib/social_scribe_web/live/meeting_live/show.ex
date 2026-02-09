defmodule SocialScribeWeb.MeetingLive.Show do
  @moduledoc """
  LiveView for the meeting detail page. Displays transcript, follow-up email,
  automation results, and CRM update modals (HubSpot, Salesforce).

  Handles generic CRM operations (search, suggest, apply) via parameterized
  `handle_info` callbacks that dispatch to the appropriate provider.
  """
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.PlatformLogo
  import SocialScribeWeb.ClipboardButton
  import SocialScribeWeb.ModalComponents, only: [crm_modal: 1]

  alias SocialScribe.Meetings
  alias SocialScribe.Automations
  alias SocialScribe.Accounts
  alias SocialScribe.CrmApiBehaviour
  alias SocialScribe.CrmSuggestions
  alias SocialScribe.CRM.ProviderConfig

  @valid_crm_names ProviderConfig.names()
  @crm_actions Enum.map(@valid_crm_names, &String.to_existing_atom/1)

  @impl true
  def mount(%{"id" => meeting_id}, _session, socket) do
    meeting = Meetings.get_meeting_with_details(meeting_id)

    user_has_automations =
      Automations.list_active_user_automations(socket.assigns.current_user.id)
      |> length()
      |> Kernel.>(0)

    automation_results = Automations.list_automation_results_for_meeting(meeting_id)

    if meeting.calendar_event.user_id != socket.assigns.current_user.id do
      socket =
        socket
        |> put_flash(:error, "You do not have permission to view this meeting.")
        |> redirect(to: ~p"/dashboard/meetings")

      {:error, socket}
    else
      crm_credentials =
        ProviderConfig.all()
        |> Enum.reduce(%{}, fn provider, acc ->
          case Accounts.get_user_crm_credential(socket.assigns.current_user.id, provider.name) do
            nil -> acc
            credential -> Map.put(acc, provider.name, credential)
          end
        end)

      socket =
        socket
        |> assign(:page_title, "Meeting Details: #{meeting.title}")
        |> assign(:meeting, meeting)
        |> assign(:automation_results, automation_results)
        |> assign(:user_has_automations, user_has_automations)
        |> assign(:crm_credentials, crm_credentials)
        |> assign(:crm_actions, @crm_actions)
        |> assign(:active_crm_config, nil)
        |> assign(:active_crm_credential, nil)
        |> assign(
          :follow_up_email_form,
          to_form(%{
            "follow_up_email" => ""
          })
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"automation_result_id" => automation_result_id}, _uri, socket) do
    automation_result = Automations.get_automation_result!(automation_result_id)
    automation = Automations.get_automation!(automation_result.automation_id)

    socket =
      socket
      |> assign(:automation_result, automation_result)
      |> assign(:automation, automation)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{live_action: action}} = socket)
      when action in @crm_actions do
    crm_name = Atom.to_string(action)
    crm_config = ProviderConfig.get(crm_name)
    credential = Map.get(socket.assigns.crm_credentials, crm_name)

    {:noreply,
     socket
     |> assign(:active_crm_config, crm_config)
     |> assign(:active_crm_credential, credential)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate-follow-up-email", params, socket) do
    socket =
      socket
      |> assign(:follow_up_email_form, to_form(params))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:crm_search, crm_name, query, credential}, socket)
      when crm_name in @valid_crm_names do
    api = CrmApiBehaviour.impl(crm_name)

    case api.search_contacts(credential, query) do
      {:ok, contacts} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "#{crm_name}-modal",
          contacts: contacts,
          searching: false
        )

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "#{crm_name}-modal",
          error: "Failed to search contacts: #{inspect(reason)}",
          searching: false
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:generate_crm_suggestions, crm_name, contact, meeting, _credential}, socket)
      when crm_name in @valid_crm_names do
    crm_config = ProviderConfig.get(crm_name)

    case CrmSuggestions.generate_suggestions_from_meeting(
           meeting,
           contact.display_name,
           crm_config
         ) do
      {:ok, suggestions} ->
        merged = CrmSuggestions.merge_with_contact(suggestions, contact)

        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "#{crm_name}-modal",
          step: :suggestions,
          suggestions: merged,
          loading: false
        )

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "#{crm_name}-modal",
          error: "Failed to generate suggestions: #{inspect(reason)}",
          loading: false
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:generate_suggestions_for_new_contact, crm_name, meeting, query}, socket)
      when crm_name in @valid_crm_names do
    crm_config = ProviderConfig.get(crm_name)

    case CrmSuggestions.generate_suggestions_from_meeting(meeting, query, crm_config) do
      {:ok, suggestions} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "#{crm_name}-modal",
          step: :creating_new,
          suggestions: suggestions,
          loading: false
        )

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "#{crm_name}-modal",
          error: "Failed to generate suggestions: #{inspect(reason)}",
          loading: false
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:create_crm_contact, crm_name, properties, credential}, socket)
      when crm_name in @valid_crm_names do
    api = CrmApiBehaviour.impl(crm_name)
    crm_config = ProviderConfig.get(crm_name)

    case api.create_contact(credential, properties) do
      {:ok, _contact} ->
        socket =
          socket
          |> put_flash(:info, "Successfully created contact in #{crm_config.display_name}")
          |> push_patch(to: ~p"/dashboard/meetings/#{socket.assigns.meeting}")

        {:noreply, socket}

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "#{crm_name}-modal",
          error: "Failed to create contact: #{inspect(reason)}",
          loading: false
        )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:apply_crm_updates, crm_name, updates, contact, credential}, socket)
      when crm_name in @valid_crm_names do
    api = CrmApiBehaviour.impl(crm_name)
    crm_config = ProviderConfig.get(crm_name)

    case api.update_contact(credential, contact.id, updates) do
      {:ok, _updated_contact} ->
        socket =
          socket
          |> put_flash(
            :info,
            "Successfully updated #{map_size(updates)} field(s) in #{crm_config.display_name}"
          )
          |> push_patch(to: ~p"/dashboard/meetings/#{socket.assigns.meeting}")

        {:noreply, socket}

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "#{crm_name}-modal",
          error: "Failed to update contact: #{inspect(reason)}",
          loading: false
        )

        {:noreply, socket}
    end
  end

  defp format_duration(nil), do: "N/A"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    cond do
      minutes > 0 && remaining_seconds > 0 -> "#{minutes} min #{remaining_seconds} sec"
      minutes > 0 -> "#{minutes} min"
      seconds > 0 -> "#{seconds} sec"
      true -> "Less than a second"
    end
  end

  attr :meeting_transcript, :map, required: true

  defp transcript_content(assigns) do
    has_transcript =
      assigns.meeting_transcript &&
        assigns.meeting_transcript.content &&
        Map.get(assigns.meeting_transcript.content, "data") &&
        Enum.any?(Map.get(assigns.meeting_transcript.content, "data"))

    assigns =
      assigns
      |> assign(:has_transcript, has_transcript)

    ~H"""
    <div class="bg-white shadow-xl rounded-lg p-6 md:p-8">
      <h2 class="text-2xl font-semibold mb-4 text-slate-700">
        Meeting Transcript
      </h2>
      <div class="prose prose-sm sm:prose max-w-none h-96 overflow-y-auto pr-2">
        <%= if @has_transcript do %>
          <div :for={segment <- @meeting_transcript.content["data"]} class="mb-3">
            <p>
              <span class="font-semibold text-indigo-600">
                {get_speaker_name(segment)}:
              </span>
              {Enum.map_join(segment["words"] || [], " ", & &1["text"])}
            </p>
          </div>
        <% else %>
          <p class="text-slate-500">
            Transcript not available for this meeting.
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  defp get_speaker_name(%{"participant" => %{"name" => name}}) when is_binary(name), do: name
  defp get_speaker_name(%{"speaker" => name}) when is_binary(name), do: name
  defp get_speaker_name(_), do: "Unknown Speaker"
end
