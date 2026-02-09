defmodule SocialScribe.Workers.CrmTokenRefresher do
  @moduledoc """
  Oban worker that proactively refreshes CRM OAuth tokens before they expire.
  Runs per-provider via args. Refreshes tokens expiring within 10 minutes.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias SocialScribe.Repo
  alias SocialScribe.Accounts.UserCredential

  import Ecto.Query

  require Logger

  @refresh_threshold_minutes 10

  @default_refreshers %{
    "hubspot" => SocialScribe.HubspotTokenRefresher,
    "salesforce" => SocialScribe.SalesforceTokenRefresher
  }

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"provider" => provider}}) do
    Logger.info("Running proactive #{provider} token refresh check...")
    refresher = get_refresher(provider)

    case get_expiring_credentials(provider) do
      [] ->
        Logger.debug("No #{provider} tokens expiring soon")
        :ok

      credentials ->
        Logger.info(
          "Found #{length(credentials)} #{provider} token(s) expiring soon, refreshing..."
        )

        refresh_all(credentials, refresher, provider)
    end
  end

  defp get_refresher(provider) do
    refreshers = Application.get_env(:social_scribe, :crm_token_refreshers, @default_refreshers)
    Map.fetch!(refreshers, provider)
  end

  defp get_expiring_credentials(provider) do
    threshold = DateTime.add(DateTime.utc_now(), @refresh_threshold_minutes, :minute)

    from(c in UserCredential,
      where: c.provider == ^provider,
      where: c.expires_at < ^threshold,
      where: not is_nil(c.refresh_token)
    )
    |> Repo.all()
  end

  defp refresh_all(credentials, refresher, provider) do
    Enum.each(credentials, fn credential ->
      case refresher.refresh_credential(credential) do
        {:ok, _} ->
          Logger.info("Proactively refreshed #{provider} token for credential #{credential.id}")

        {:error, reason} ->
          Logger.error(
            "Failed to proactively refresh #{provider} token for credential #{credential.id}: #{sanitize_log(reason)}"
          )
      end
    end)

    :ok
  end

  defp sanitize_log(body) when is_map(body) do
    body
    |> Map.take(["error", "errorCode", "message", "error_description", "status"])
    |> inspect()
  end

  defp sanitize_log({status, body}) when is_integer(status) and is_map(body) do
    "{#{status}, #{sanitize_log(body)}}"
  end

  defp sanitize_log(other), do: inspect(other)
end
