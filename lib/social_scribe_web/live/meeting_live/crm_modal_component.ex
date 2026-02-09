defmodule SocialScribeWeb.MeetingLive.CrmModalComponent do
  @moduledoc """
  Generic CRM modal LiveComponent used by all CRM providers.

  Implements the search -> select -> suggest -> apply workflow:
  1. User searches for a contact via the CRM API
  2. Selects a contact from results
  3. AI generates field update suggestions from the meeting transcript
  4. User reviews and selectively applies updates

  Parameterized via `crm_config` from `CRM.ProviderConfig`.
  """
  use SocialScribeWeb, :live_component

  import SocialScribeWeb.ModalComponents

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :patch, ~p"/dashboard/meetings/#{assigns.meeting}")
    assigns = assign_new(assigns, :modal_id, fn -> "#{assigns.crm_config.id}-modal-wrapper" end)

    ~H"""
    <div class="space-y-6">
      <%= if @step == :creating_new do %>
        <div>
          <div class="flex items-center gap-2">
            <button
              type="button"
              phx-click="back_to_search"
              phx-target={@myself}
              class="text-slate-400 hover:text-slate-600"
            >
              <.icon name="hero-arrow-left" class="h-5 w-5" />
            </button>
            <h2 id={"#{@modal_id}-title"} class="text-xl font-medium tracking-tight text-slate-900">
              Create New Contact in {@crm_config.name}
            </h2>
          </div>
          <p
            id={"#{@modal_id}-description"}
            class="mt-2 text-base font-light leading-7 text-slate-500"
          >
            Review the AI-suggested fields below and create a new contact.
          </p>
        </div>

        <.suggestions_section
          suggestions={@suggestions}
          loading={@loading}
          myself={@myself}
          patch={@patch}
          crm_config={@crm_config}
          action="create_contact"
          creating={true}
        />
      <% else %>
        <div>
          <h2 id={"#{@modal_id}-title"} class="text-xl font-medium tracking-tight text-slate-900">
            Update in {@crm_config.name}
          </h2>
          <p
            id={"#{@modal_id}-description"}
            class="mt-2 text-base font-light leading-7 text-slate-500"
          >
            {@crm_config.description}
          </p>
        </div>

        <.contact_select
          selected_contact={@selected_contact}
          contacts={@contacts}
          loading={@searching}
          open={@dropdown_open}
          query={@query}
          target={@myself}
          error={@error}
        />

        <%= if @selected_contact do %>
          <.suggestions_section
            suggestions={@suggestions}
            loading={@loading}
            myself={@myself}
            patch={@patch}
            crm_config={@crm_config}
          />
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :suggestions, :list, required: true
  attr :loading, :boolean, required: true
  attr :myself, :any, required: true
  attr :patch, :string, required: true
  attr :crm_config, :map, required: true
  attr :action, :string, default: "apply_updates"
  attr :creating, :boolean, default: false

  defp suggestions_section(assigns) do
    assigns = assign(assigns, :selected_count, Enum.count(assigns.suggestions, & &1.apply))

    ~H"""
    <div class="space-y-4">
      <%= if @loading do %>
        <div class="text-center py-8 text-slate-500">
          <.icon name="hero-arrow-path" class="h-6 w-6 animate-spin mx-auto mb-2" />
          <p>Generating suggestions...</p>
        </div>
      <% else %>
        <%= if Enum.empty?(@suggestions) do %>
          <.empty_state
            message="No update suggestions found from this meeting."
            submessage="The AI didn't detect any new contact information in the transcript."
          />
        <% else %>
          <form phx-submit={@action} phx-change="toggle_suggestion" phx-target={@myself}>
            <div class="space-y-4 max-h-[60vh] overflow-y-auto pr-2">
              <.suggestion_card :for={suggestion <- @suggestions} suggestion={suggestion} />
            </div>

            <.modal_footer
              cancel_patch={@patch}
              submit_text={
                if @creating, do: "Create in #{@crm_config.name}", else: @crm_config.submit_text
              }
              submit_class={@crm_config.submit_class}
              disabled={@selected_count == 0}
              loading={@loading}
              loading_text={if @creating, do: "Creating...", else: "Updating..."}
              info_text={
                if @creating,
                  do: "Creating new contact with #{@selected_count} fields",
                  else: "1 object, #{@selected_count} fields in 1 integration selected to update"
              }
            />
          </form>
        <% end %>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> maybe_select_all_suggestions(assigns)
      |> assign_new(:step, fn -> :search end)
      |> assign_new(:query, fn -> "" end)
      |> assign_new(:contacts, fn -> [] end)
      |> assign_new(:selected_contact, fn -> nil end)
      |> assign_new(:suggestions, fn -> [] end)
      |> assign_new(:loading, fn -> false end)
      |> assign_new(:searching, fn -> false end)
      |> assign_new(:dropdown_open, fn -> false end)
      |> assign_new(:error, fn -> nil end)

    {:ok, socket}
  end

  defp maybe_select_all_suggestions(socket, %{suggestions: suggestions})
       when is_list(suggestions) do
    assign(socket, suggestions: Enum.map(suggestions, &Map.put(&1, :apply, true)))
  end

  defp maybe_select_all_suggestions(socket, _assigns), do: socket

  @impl true
  def handle_event("contact_search", %{"value" => query}, socket) do
    query = String.trim(query)

    if String.length(query) >= 2 do
      socket = assign(socket, searching: true, error: nil, query: query, dropdown_open: true)
      send(self(), {:crm_search, socket.assigns.crm_config.id, query, socket.assigns.credential})
      {:noreply, socket}
    else
      {:noreply, assign(socket, query: query, contacts: [], dropdown_open: query != "")}
    end
  end

  @impl true
  def handle_event("open_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: true)}
  end

  @impl true
  def handle_event("close_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: false)}
  end

  @impl true
  def handle_event("toggle_contact_dropdown", _params, socket) do
    if socket.assigns.dropdown_open do
      {:noreply, assign(socket, dropdown_open: false)}
    else
      socket = assign(socket, dropdown_open: true, searching: true)

      query =
        "#{socket.assigns.selected_contact.firstname} #{socket.assigns.selected_contact.lastname}"

      send(self(), {:crm_search, socket.assigns.crm_config.id, query, socket.assigns.credential})
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_contact", %{"id" => contact_id}, socket) do
    contact = Enum.find(socket.assigns.contacts, &(&1.id == contact_id))

    if contact do
      socket =
        assign(socket,
          loading: true,
          selected_contact: contact,
          error: nil,
          dropdown_open: false,
          query: "",
          suggestions: []
        )

      send(
        self(),
        {:generate_crm_suggestions, socket.assigns.crm_config.id, contact, socket.assigns.meeting,
         socket.assigns.credential}
      )

      {:noreply, socket}
    else
      {:noreply, assign(socket, error: "Contact not found")}
    end
  end

  @impl true
  def handle_event("clear_contact", _params, socket) do
    {:noreply,
     assign(socket,
       step: :search,
       selected_contact: nil,
       suggestions: [],
       loading: false,
       searching: false,
       dropdown_open: false,
       contacts: [],
       query: "",
       error: nil
     )}
  end

  @impl true
  def handle_event("toggle_suggestion", params, socket) do
    applied_fields = Map.get(params, "apply", %{})
    values = Map.get(params, "values", %{})
    checked_fields = Map.keys(applied_fields)

    updated_suggestions =
      Enum.map(socket.assigns.suggestions, fn suggestion ->
        apply? = suggestion.field in checked_fields

        suggestion =
          case Map.get(values, suggestion.field) do
            nil -> suggestion
            new_value -> %{suggestion | new_value: new_value}
          end

        %{suggestion | apply: apply?}
      end)

    {:noreply, assign(socket, suggestions: updated_suggestions)}
  end

  @impl true
  def handle_event("start_create_contact", _params, socket) do
    socket =
      assign(socket,
        step: :creating_new,
        loading: true,
        suggestions: [],
        error: nil,
        dropdown_open: false,
        selected_contact: nil
      )

    send(
      self(),
      {:generate_suggestions_for_new_contact, socket.assigns.crm_config.id,
       socket.assigns.meeting, socket.assigns.query}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("back_to_search", _params, socket) do
    {:noreply,
     assign(socket,
       step: :search,
       suggestions: [],
       loading: false,
       error: nil
     )}
  end

  @impl true
  def handle_event("create_contact", %{"apply" => selected, "values" => values}, socket) do
    socket = assign(socket, loading: true, error: nil)

    properties =
      selected
      |> Map.keys()
      |> Enum.reduce(%{}, fn field, acc ->
        Map.put(acc, field, Map.get(values, field, ""))
      end)

    send(
      self(),
      {:create_crm_contact, socket.assigns.crm_config.id, properties, socket.assigns.credential}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_contact", _params, socket) do
    {:noreply, assign(socket, error: "Please select at least one field")}
  end

  @impl true
  def handle_event("apply_updates", %{"apply" => selected, "values" => values}, socket) do
    socket = assign(socket, loading: true, error: nil)

    updates =
      selected
      |> Map.keys()
      |> Enum.reduce(%{}, fn field, acc ->
        Map.put(acc, field, Map.get(values, field, ""))
      end)

    send(
      self(),
      {:apply_crm_updates, socket.assigns.crm_config.id, updates, socket.assigns.selected_contact,
       socket.assigns.credential}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("apply_updates", _params, socket) do
    {:noreply, assign(socket, error: "Please select at least one field to update")}
  end
end
