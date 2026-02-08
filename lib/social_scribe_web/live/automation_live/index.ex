defmodule SocialScribeWeb.AutomationLive.Index do
  @moduledoc """
  LiveView listing all automations for the current user with CRUD actions.
  """
  use SocialScribeWeb, :live_view

  alias SocialScribe.Automations
  alias SocialScribe.Automations.Automation

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       :automations,
       Automations.list_user_automations(socket.assigns.current_user.id)
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    automation = Automations.get_automation!(id)

    if automation.user_id != socket.assigns.current_user.id do
      socket
      |> put_flash(:error, "Not authorized")
      |> push_navigate(to: ~p"/dashboard/automations")
    else
      socket
      |> assign(:page_title, "Edit Automation")
      |> assign(:automation, automation)
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Automation")
    |> assign(:automation, %Automation{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Automations")
    |> assign(:automation, nil)
  end

  @impl true
  def handle_info({SocialScribeWeb.AutomationLive.FormComponent, {:saved, _automation}}, socket) do
    {:noreply,
     assign(
       socket,
       :automations,
       Automations.list_user_automations(socket.assigns.current_user.id)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    automation = Automations.get_automation!(id)

    if automation.user_id == socket.assigns.current_user.id do
      {:ok, _} = Automations.delete_automation(automation)

      {:noreply,
       assign(
         socket,
         :automations,
         Enum.filter(socket.assigns.automations, fn a -> a.id != automation.id end)
       )}
    else
      {:noreply, put_flash(socket, :error, "Not authorized")}
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
          socket =
            socket
            |> assign(
              :automations,
              Enum.map(socket.assigns.automations, fn a ->
                if a.id == updated_automation.id do
                  updated_automation
                else
                  a
                end
              end)
            )

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply,
           put_flash(socket, :error, "You can only have one active automation per platform")}
      end
    end
  end
end
