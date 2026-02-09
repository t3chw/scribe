defmodule SocialScribeWeb.MeetingLive.Index do
  @moduledoc """
  LiveView listing all processed meetings for the current user.
  """
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.PlatformLogo

  alias SocialScribe.Meetings

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        SocialScribe.PubSub,
        "user:#{socket.assigns.current_user.id}:meetings"
      )
    end

    meetings = Meetings.list_user_meetings(socket.assigns.current_user)

    socket =
      socket
      |> assign(:page_title, "Past Meetings")
      |> assign(:meetings, meetings)

    {:ok, socket}
  end

  @impl true
  def handle_info({:meeting_created, _meeting}, socket) do
    meetings = Meetings.list_user_meetings(socket.assigns.current_user)
    {:noreply, assign(socket, :meetings, meetings)}
  end

  defp format_duration(nil), do: "N/A"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    "#{minutes} min"
  end
end
