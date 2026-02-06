defmodule SocialScribeWeb.ChatLive.ChatPanelComponent do
  use SocialScribeWeb, :live_component

  alias SocialScribe.Chat

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
              I can answer questions about Jump meetings and data - just ask!
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
                  <div class="whitespace-pre-wrap break-words">{message.content}</div>
                </div>
              <% else %>
                <div class="max-w-[85%] text-sm text-slate-800">
                  <div class="whitespace-pre-wrap break-words">{message.content}</div>
                  <%= if message.metadata["sources"] && Enum.any?(message.metadata["sources"]) do %>
                    <div class="mt-2 flex items-center gap-2 flex-wrap">
                      <span
                        :for={source <- message.metadata["sources"]}
                        class="inline-flex items-center gap-1.5 text-xs text-slate-500"
                      >
                        <span class="w-5 h-5 rounded-full bg-slate-200 flex items-center justify-center text-[10px] font-medium text-slate-600 flex-shrink-0">
                          {String.at(source["name"] || "", 0)}
                        </span>
                        {source["name"]}
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
            <textarea
              id="chat-input"
              name="message"
              rows="2"
              value={@input_value}
              placeholder="Ask anything about your meetings"
              phx-hook="ChatInput"
              class="w-full resize-none border-0 px-3 py-2 text-sm focus:outline-none focus:ring-0 placeholder-slate-400"
              phx-target={@myself}
            ></textarea>
            <div class="flex items-center justify-between px-3 pb-2">
              <div class="flex items-center gap-1">
                <span class="w-5 h-5 rounded-full bg-slate-100 flex items-center justify-center">
                  <svg
                    class="w-3 h-3 text-slate-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                    stroke-width="2"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m9.86-2.813a4.5 4.5 0 00-6.364-6.364L4.5 8.25"
                    />
                  </svg>
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

    {:noreply,
     assign(socket,
       active_tab: :chat,
       conversation: conversation,
       messages: conversation.messages
     )}
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

  defp show_timestamp?(message, idx, messages) do
    case idx do
      0 ->
        true

      _ ->
        prev = Enum.at(messages, idx - 1)

        prev && message.inserted_at &&
          NaiveDateTime.diff(message.inserted_at, prev.inserted_at, :minute) > 5
    end
  end

  defp format_timestamp(nil), do: ""

  defp format_timestamp(%NaiveDateTime{} = dt) do
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
end
