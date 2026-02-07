defmodule SocialScribeWeb.ChatLive.ChatPanelComponent do
  use SocialScribeWeb, :live_component

  alias SocialScribe.Chat
  alias SocialScribe.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="chat-panel"
      class={[
        "fixed right-0 top-0 h-full bg-white shadow-2xl border-l border-slate-200 z-40 flex flex-col transition-transform duration-300 ease-in-out",
        if(@open, do: "translate-x-0", else: "translate-x-full")
      ]}
      style="width: 400px;"
    >
      <%!-- Header --%>
      <div class="flex items-center justify-between px-4 py-3 border-b border-slate-200 bg-white">
        <h2 class="text-lg font-bold text-slate-900">Ask Anything</h2>
        <button
          type="button"
          phx-click="toggle_chat"
          class="text-slate-400 hover:text-slate-600 transition-colors"
          aria-label="Close chat"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13 5l7 7-7 7M6 5l7 7-7 7" />
          </svg>
        </button>
      </div>

      <%!-- Tabs --%>
      <div class="flex items-center border-b border-slate-200 px-1">
        <button
          type="button"
          phx-click="switch_tab"
          phx-value-tab="chat"
          phx-target={@myself}
          class={[
            "px-3 py-2.5 text-sm font-medium transition-colors",
            if(@active_tab == :chat,
              do: "text-slate-900 font-bold border-b-2 border-slate-900",
              else: "text-slate-400 hover:text-slate-600"
            )
          ]}
        >
          Chat
        </button>
        <button
          type="button"
          phx-click="switch_tab"
          phx-value-tab="history"
          phx-target={@myself}
          class={[
            "px-3 py-2.5 text-sm font-medium transition-colors",
            if(@active_tab == :history,
              do: "text-slate-900 font-bold border-b-2 border-slate-900",
              else: "text-slate-400 hover:text-slate-600"
            )
          ]}
        >
          History
        </button>
        <div class="flex-1"></div>
        <button
          type="button"
          phx-click="new_conversation"
          phx-target={@myself}
          class="mr-2 text-slate-400 hover:text-slate-600 transition-colors"
          aria-label="New conversation"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
        </button>
      </div>

      <%!-- Content --%>
      <%= if @active_tab == :chat do %>
        <.chat_tab
          messages={@messages}
          loading={@loading}
          input_value={@input_value}
          myself={@myself}
          conversation={@conversation}
          connected_sources={@connected_sources}
          mention_suggestions={@mention_suggestions}
        />
      <% else %>
        <.history_tab conversations={@conversations} myself={@myself} />
      <% end %>
    </div>
    """
  end

  attr :messages, :list, required: true
  attr :loading, :boolean, required: true
  attr :input_value, :string, required: true
  attr :myself, :any, required: true
  attr :conversation, :any, required: true
  attr :connected_sources, :list, required: true
  attr :mention_suggestions, :list, required: true

  defp chat_tab(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col min-h-0">
      <%!-- Messages area --%>
      <div id="chat-messages" phx-hook="ChatScroll" class="flex-1 overflow-y-auto p-4 space-y-3">
        <%= if Enum.empty?(@messages) do %>
          <div class="flex flex-col items-center justify-center h-full px-6">
            <div class="w-10 h-10 rounded-full bg-slate-100 flex items-center justify-center mb-3">
              <svg
                class="w-5 h-5 text-slate-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="1.5"
                  d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                />
              </svg>
            </div>
            <p class="text-sm text-slate-500 text-center">
              I can answer questions about your meetings and data - just ask!
            </p>
          </div>
        <% else %>
          <%= for {message, idx} <- Enum.with_index(@messages) do %>
            <.timestamp_separator
              :if={show_timestamp?(message, idx, @messages)}
              timestamp={message.inserted_at}
            />
            <div class={["flex", if(message.role == "user", do: "justify-end", else: "justify-start")]}>
              <%= if message.role == "user" do %>
                <div class="max-w-[85%] rounded-2xl rounded-br-md px-4 py-2.5 text-sm bg-[#f1f3f4] text-slate-800">
                  <div class="break-words">
                    <%= for segment <- parse_user_message_segments(message.content) do %>
                      <.render_segment segment={segment} />
                    <% end %>
                  </div>
                </div>
              <% else %>
                <div class="max-w-[85%] text-sm text-slate-800">
                  <div class="break-words">
                    <%= for segment <- parse_ai_message_segments(message.content, message.metadata["mentions"]) do %>
                      <.render_segment segment={segment} />
                    <% end %>
                  </div>
                  <%= if message.metadata["sources"] && Enum.any?(message.metadata["sources"]) do %>
                    <div class="mt-2 flex items-center gap-1.5 flex-wrap">
                      <span class="text-xs text-teal-600 font-medium">Sources</span>
                      <span
                        :for={source <- unique_source_types(message.metadata["sources"])}
                        class="inline-flex items-center gap-1 text-xs text-slate-500"
                        title={source_tooltip(source)}
                      >
                        <span class={[
                          "w-3 h-3 rounded-full flex-shrink-0",
                          source_dot_color(source)
                        ]}>
                        </span>
                        {source_label(source)}
                      </span>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
          <div :if={@loading} class="flex justify-start">
            <div class="text-sm text-slate-400">
              <div class="flex space-x-1.5">
                <div
                  class="w-2 h-2 bg-slate-300 rounded-full animate-bounce"
                  style="animation-delay: 0ms"
                >
                </div>
                <div
                  class="w-2 h-2 bg-slate-300 rounded-full animate-bounce"
                  style="animation-delay: 150ms"
                >
                </div>
                <div
                  class="w-2 h-2 bg-slate-300 rounded-full animate-bounce"
                  style="animation-delay: 300ms"
                >
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Input area --%>
      <div class="border-t border-slate-200 p-3">
        <form phx-submit="send_message" phx-target={@myself}>
          <div class="border border-slate-300 rounded-xl overflow-hidden focus-within:ring-2 focus-within:ring-slate-400 focus-within:border-slate-400">
            <div class="px-3 pt-2">
              <span class="inline-flex items-center gap-1 text-xs text-slate-400 bg-slate-100 rounded-full px-2 py-0.5">
                <svg
                  class="w-3 h-3"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                  />
                </svg>
                @ Add context
              </span>
            </div>
            <div
              :if={@mention_suggestions != []}
              id="mention-suggestions"
              class="mx-3 mb-1 border border-slate-200 rounded-lg bg-white shadow-lg max-h-40 overflow-y-auto"
              phx-click-away="clear_mentions"
              phx-target={@myself}
            >
              <button
                :for={{suggestion, idx} <- Enum.with_index(@mention_suggestions)}
                type="button"
                id={"mention-suggestion-#{idx}"}
                class="w-full px-3 py-2 text-left text-sm hover:bg-slate-100 flex items-center gap-2"
                phx-click="select_mention"
                phx-value-name={suggestion.name}
                phx-target={@myself}
                data-mention-index={idx}
              >
                <span class={[
                  "w-3 h-3 rounded-full flex-shrink-0",
                  mention_source_color(suggestion.source)
                ]}>
                </span>
                <span class="truncate">{suggestion.name}</span>
                <span class="text-xs text-slate-400 ml-auto">
                  {mention_source_label(suggestion.source)}
                </span>
              </button>
            </div>
            <div class="relative">
              <div
                id="chat-input-mirror"
                aria-hidden="true"
                class="w-full px-3 py-2 text-sm whitespace-pre-wrap break-words pointer-events-none"
              >
              </div>
              <textarea
                id="chat-input"
                name="message"
                rows="2"
                value={@input_value}
                placeholder="Ask anything about your meetings"
                phx-hook="ChatInput"
                class="absolute inset-0 w-full h-full resize-none border-0 px-3 py-2 text-sm focus:outline-none focus:ring-0 placeholder-slate-400 bg-transparent"
                style="color: transparent; caret-color: #1e293b;"
                phx-target={@myself}
              ></textarea>
            </div>
            <div class="flex items-center justify-between px-3 pb-2">
              <div class="flex items-center gap-1.5">
                <span class="text-xs text-teal-600 font-medium">Sources</span>
                <span
                  :for={source <- @connected_sources}
                  class={["w-4 h-4 rounded-full", connected_source_color(source)]}
                >
                </span>
              </div>
              <button
                type="submit"
                disabled={@loading}
                class="w-7 h-7 rounded-full bg-slate-900 flex items-center justify-center text-white hover:bg-slate-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <svg
                  class="w-3.5 h-3.5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  stroke-width="2.5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M4.5 10.5L12 3m0 0l7.5 7.5M12 3v18"
                  />
                </svg>
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  attr :segment, :any, required: true

  defp render_segment(%{segment: {:mention, name}} = assigns) do
    assigns = assign(assigns, :name, name)

    ~H"""
    <span class="inline-flex items-center gap-1 align-middle bg-slate-200 rounded-full px-2 py-0.5 mx-0.5">
      <span class="w-4 h-4 rounded-full bg-slate-400 inline-flex items-center justify-center flex-shrink-0">
        <svg
          class="w-2.5 h-2.5 text-white"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          stroke-width="2"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
          />
        </svg>
      </span>
      <span class="font-medium text-slate-800">{@name}</span>
    </span>
    """
  end

  defp render_segment(%{segment: {:text, text}} = assigns) do
    assigns = assign(assigns, :html, text_to_html(text))

    ~H"""
    {Phoenix.HTML.raw(@html)}
    """
  end

  defp text_to_html(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace("\n", "<br>")
  end

  attr :timestamp, :any, required: true

  defp timestamp_separator(assigns) do
    ~H"""
    <div class="flex items-center justify-center py-1">
      <span class="text-xs text-slate-400">{format_timestamp(@timestamp)}</span>
    </div>
    """
  end

  attr :conversations, :list, required: true
  attr :myself, :any, required: true

  defp history_tab(assigns) do
    ~H"""
    <div class="flex-1 overflow-y-auto">
      <%= if Enum.empty?(@conversations) do %>
        <div class="flex flex-col items-center justify-center h-full text-slate-400 px-4">
          <p class="text-sm">No conversation history yet.</p>
        </div>
      <% else %>
        <div class="divide-y divide-slate-100">
          <button
            :for={conversation <- @conversations}
            type="button"
            phx-click="load_conversation"
            phx-value-id={conversation.id}
            phx-target={@myself}
            class="w-full px-4 py-3 text-left hover:bg-slate-50 transition-colors"
          >
            <div class="text-sm font-medium text-slate-700 truncate">
              {conversation.title || "Untitled conversation"}
            </div>
            <div class="text-xs text-slate-400 mt-0.5">
              {Calendar.strftime(conversation.inserted_at, "%b %d, %Y %I:%M %p")}
            </div>
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:open, fn -> false end)
      |> assign_new(:active_tab, fn -> :chat end)
      |> assign_new(:messages, fn -> [] end)
      |> assign_new(:conversations, fn -> [] end)
      |> assign_new(:conversation, fn -> nil end)
      |> assign_new(:loading, fn -> false end)
      |> assign_new(:input_value, fn -> "" end)
      |> assign_new(:connected_sources, fn ->
        get_connected_sources(assigns[:current_user])
      end)
      |> assign_new(:mention_suggestions, fn -> [] end)

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => "history"}, socket) do
    conversations = Chat.list_conversations(socket.assigns.current_user.id)
    {:noreply, assign(socket, active_tab: :history, conversations: conversations)}
  end

  def handle_event("switch_tab", %{"tab" => "chat"}, socket) do
    {:noreply, assign(socket, active_tab: :chat)}
  end

  @impl true
  def handle_event("new_conversation", _params, socket) do
    {:noreply,
     assign(socket,
       conversation: nil,
       messages: [],
       loading: false,
       input_value: "",
       active_tab: :chat
     )}
  end

  @impl true
  def handle_event("load_conversation", %{"id" => id}, socket) do
    conversation = Chat.get_conversation_with_messages(id)

    if conversation.user_id != socket.assigns.current_user.id do
      {:noreply, socket}
    else
      {:noreply,
       assign(socket,
         active_tab: :chat,
         conversation: conversation,
         messages: conversation.messages
       )}
    end
  end

  @impl true
  def handle_event("search_mentions", %{"query" => query}, socket) do
    suggestions =
      if String.length(String.trim(query)) >= 1 do
        user_id = socket.assigns.current_user.id

        # Meeting participants (existing, fast local query)
        meeting_names = SocialScribe.Meetings.search_user_participants(user_id, query)
        meeting_suggestions = Enum.map(meeting_names, &%{name: &1, source: "meetings"})

        # CRM contacts (new, fast local query)
        crm_suggestions = SocialScribe.CRM.search_contacts(user_id, query, 5)

        # Merge, dedup by name (meetings first), cap at 8
        (meeting_suggestions ++ crm_suggestions)
        |> Enum.uniq_by(& &1.name)
        |> Enum.take(8)
      else
        []
      end

    {:noreply, assign(socket, :mention_suggestions, suggestions)}
  end

  @impl true
  def handle_event("clear_mentions", _params, socket) do
    {:noreply, assign(socket, :mention_suggestions, [])}
  end

  @impl true
  def handle_event("select_mention", %{"name" => name}, socket) do
    socket =
      socket
      |> assign(:mention_suggestions, [])
      |> push_event("mention_selected", %{name: name})

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    message = String.trim(message)

    if message == "" do
      {:noreply, socket}
    else
      {conversation, socket} = ensure_conversation(socket, message)

      {:ok, user_msg} =
        Chat.add_message(conversation.id, %{
          role: "user",
          content: message,
          metadata: %{}
        })

      messages = socket.assigns.messages ++ [user_msg]
      socket = assign(socket, messages: messages, loading: true, input_value: "")

      send(self(), {:chat_ai_process, conversation.id, message, socket.assigns.current_user.id})

      {:noreply, socket}
    end
  end

  # --- Private Helpers ---

  defp ensure_conversation(socket, message) do
    case socket.assigns.conversation do
      nil ->
        title = String.slice(message, 0, 50)

        {:ok, conversation} =
          Chat.create_conversation(%{
            user_id: socket.assigns.current_user.id,
            title: title
          })

        {conversation, assign(socket, conversation: conversation)}

      conversation ->
        {conversation, socket}
    end
  end

  defp get_connected_sources(nil), do: [:meetings]

  defp get_connected_sources(current_user) do
    sources = [:meetings]

    sources =
      if Accounts.get_user_hubspot_credential(current_user.id),
        do: sources ++ [:hubspot],
        else: sources

    sources =
      if Accounts.get_user_salesforce_credential(current_user.id),
        do: sources ++ [:salesforce],
        else: sources

    sources
  end

  defp show_timestamp?(message, idx, messages) do
    case idx do
      0 ->
        true

      _ ->
        prev = Enum.at(messages, idx - 1)

        prev && message.inserted_at &&
          DateTime.diff(message.inserted_at, prev.inserted_at, :minute) > 5
    end
  end

  defp format_timestamp(nil), do: ""

  defp format_timestamp(%DateTime{} = dt) do
    hour = dt.hour
    minute = dt.minute

    {h12, ampm} =
      if hour >= 12,
        do: {if(hour > 12, do: hour - 12, else: 12), "pm"},
        else: {if(hour == 0, do: 12, else: hour), "am"}

    months =
      ~w(January February March April May June July August September October November December)

    month_name = Enum.at(months, dt.month - 1)

    "#{h12}:#{String.pad_leading(Integer.to_string(minute), 2, "0")}#{ampm} - #{month_name} #{dt.day}, #{dt.year}"
  end

  defp format_timestamp(_), do: ""

  @doc false
  def parse_user_message_segments(content) do
    parts =
      Regex.split(~r/(@[A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)?)/, content, include_captures: true)

    parts
    |> Enum.map(fn part ->
      if Regex.match?(~r/^@[A-Z]/, part),
        do: {:mention, String.trim_leading(part, "@")},
        else: {:text, part}
    end)
    |> Enum.reject(fn
      {:text, t} -> String.trim(t) == ""
      _ -> false
    end)
  end

  @doc false
  def parse_ai_message_segments(content, mentions)
      when is_list(mentions) and mentions != [] do
    pattern = mentions |> Enum.map(&Regex.escape/1) |> Enum.join("|")
    regex = Regex.compile!("\\b(#{pattern})\\b")
    parts = Regex.split(regex, content, include_captures: true)

    parts
    |> Enum.map(fn part ->
      if part in mentions, do: {:mention, part}, else: {:text, part}
    end)
    |> Enum.reject(fn
      {:text, t} -> String.trim(t) == ""
      _ -> false
    end)
  end

  def parse_ai_message_segments(content, _), do: [{:text, content}]

  defp source_dot_color(%{"crm" => "hubspot"}), do: "bg-orange-500"
  defp source_dot_color(%{"crm" => "salesforce"}), do: "bg-blue-500"
  defp source_dot_color(%{"type" => "meeting"}), do: "bg-slate-800"
  defp source_dot_color(_), do: "bg-slate-400"

  defp unique_source_types(sources) do
    Enum.uniq_by(sources, fn
      %{"crm" => crm} -> "crm:#{crm}"
      %{"type" => type} -> "type:#{type}"
      _ -> "unknown"
    end)
  end

  defp source_label(%{"crm" => "hubspot"}), do: "HubSpot"
  defp source_label(%{"crm" => "salesforce"}), do: "Salesforce"
  defp source_label(%{"type" => "meeting"}), do: "Meetings"
  defp source_label(_), do: "Other"

  defp source_tooltip(%{"type" => "meeting", "title" => title, "date" => date}),
    do: "#{title} (#{date})"

  defp source_tooltip(%{"crm" => crm, "name" => name}),
    do: "#{String.capitalize(crm)}: #{name}"

  defp source_tooltip(_), do: nil

  defp connected_source_color(:meetings), do: "bg-slate-800"
  defp connected_source_color(:hubspot), do: "bg-orange-500"
  defp connected_source_color(:salesforce), do: "bg-blue-500"

  defp mention_source_color("meetings"), do: "bg-slate-800"
  defp mention_source_color("hubspot"), do: "bg-orange-500"
  defp mention_source_color("salesforce"), do: "bg-blue-500"
  defp mention_source_color(_), do: "bg-slate-400"

  defp mention_source_label("meetings"), do: "Meetings"
  defp mention_source_label("hubspot"), do: "HubSpot"
  defp mention_source_label("salesforce"), do: "Salesforce"
  defp mention_source_label(_), do: "Other"
end
