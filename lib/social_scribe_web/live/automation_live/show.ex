defmodule SocialScribeWeb.AutomationLive.Show do
  @moduledoc """
  LiveView for viewing a single automation's details and prompt template.
  """
  use SocialScribeWeb, :live_view

  alias SocialScribe.Automations

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    automation = Automations.get_automation!(id)

    if automation.user_id != socket.assigns.current_user.id do
      {:noreply,
       socket
       |> put_flash(:error, "Not authorized")
       |> push_navigate(to: ~p"/dashboard/automations")}
    else
      {:noreply,
       socket
       |> assign(:page_title, page_title(socket.assigns.live_action))
       |> assign(:automation, automation)}
    end
  end

  @impl true
  def handle_event("toggle_automation", %{"id" => id}, socket) do
    automation = Automations.get_automation!(id)

    if automation.user_id != socket.assigns.current_user.id do
      {:noreply, put_flash(socket, :error, "Not authorized")}
    else
      case Automations.update_automation(automation, %{is_active: !automation.is_active}) do
        {:ok, updated_automation} ->
          {:noreply, assign(socket, :automation, updated_automation)}

        {:error, _changeset} ->
          {:noreply,
           put_flash(socket, :error, "You can only have one active automation per platform")}
      end
    end
  end

  defp page_title(:show), do: "Show Automation"
  defp page_title(:edit), do: "Edit Automation"
end
