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

  @token_refreshers %{
    "hubspot" => SocialScribe.HubspotTokenRefresher,
    "salesforce" => SocialScribe.SalesforceTokenRefresher
  }

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"provider" => provider}}) do
    Logger.info("Running proactive #{provider} token refresh check...")
    refresher = Map.fetch!(@token_refreshers, provider)

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
            "Failed to proactively refresh #{provider} token for credential #{credential.id}: #{inspect(reason)}"
          )
      end
    end)

    :ok
  end
end
