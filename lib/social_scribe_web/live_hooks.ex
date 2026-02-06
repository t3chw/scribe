defmodule SocialScribeWeb.LiveHooks do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  alias SocialScribe.Chat
  alias SocialScribe.Chat.ChatAI

  def on_mount(:assign_current_path, _params, _session, socket) do
    socket =
      attach_hook(socket, :assign_current_path, :handle_params, &assign_current_path/3)

    {:cont, socket}
  end

  def on_mount(:assign_chat_state, _params, _session, socket) do
    socket =
      socket
      |> assign(:chat_open, false)
      |> assign(:chat_task_ref, nil)
      |> attach_hook(:chat_events, :handle_event, &handle_chat_event/3)
      |> attach_hook(:chat_info, :handle_info, &handle_chat_info/2)

    {:cont, socket}
  end

  defp assign_current_path(_params, uri, socket) do
    uri = URI.parse(uri)

    {:cont, assign(socket, :current_path, uri.path)}
  end

  defp handle_chat_event("toggle_chat", _params, socket) do
    {:halt, assign(socket, :chat_open, !socket.assigns.chat_open)}
  end

  defp handle_chat_event(_event, _params, socket) do
    {:cont, socket}
  end

  defp handle_chat_info({:chat_ai_process, conversation_id, message, user_id}, socket) do
    task =
      Task.Supervisor.async_nolink(SocialScribe.TaskSupervisor, fn ->
        conversation = Chat.get_conversation_with_messages(conversation_id)
        history = Enum.slice(conversation.messages, 0..-2//1)

        case ChatAI.process_message(message, user_id, history) do
          {:ok, %{content: content, metadata: metadata}} ->
            {:ok, assistant_msg} =
              Chat.add_message(conversation_id, %{
                role: "assistant",
                content: content,
                metadata: metadata
              })

            {:chat_ai_result, conversation_id, assistant_msg}

          {:error, reason} ->
            error_msg = "Sorry, I encountered an error: #{inspect(reason)}"

            {:ok, assistant_msg} =
              Chat.add_message(conversation_id, %{
                role: "assistant",
                content: error_msg,
                metadata: %{}
              })

            {:chat_ai_result, conversation_id, assistant_msg}
        end
      end)

    {:halt, assign(socket, :chat_task_ref, task.ref)}
  end

  defp handle_chat_info({ref, {:chat_ai_result, conversation_id, _assistant_msg}}, socket)
       when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    conversation = Chat.get_conversation_with_messages(conversation_id)

    Phoenix.LiveView.send_update(
      SocialScribeWeb.ChatLive.ChatPanelComponent,
      id: "chat-panel",
      messages: conversation.messages,
      loading: false
    )

    {:halt, assign(socket, :chat_task_ref, nil)}
  end

  defp handle_chat_info({:DOWN, ref, :process, _pid, _reason}, socket)
       when ref == socket.assigns.chat_task_ref do
    Phoenix.LiveView.send_update(
      SocialScribeWeb.ChatLive.ChatPanelComponent,
      id: "chat-panel",
      loading: false
    )

    {:halt, assign(socket, :chat_task_ref, nil)}
  end

  defp handle_chat_info(_msg, socket) do
    {:cont, socket}
  end
end
