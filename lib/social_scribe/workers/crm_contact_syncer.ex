defmodule SocialScribe.Workers.CRMContactSyncer do
  @moduledoc """
  Oban worker that syncs CRM contacts to the local crm_contacts table.

  Two modes:
  - Cron (no args): Iterates all CRM providers and syncs all users' contacts.
  - Targeted (%{"user_id" => id, "provider" => name}): Syncs one user+provider.
    Used for immediate sync on OAuth connect.
  """

  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 60]

  alias SocialScribe.Repo
  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.CRM

  import Ecto.Query

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "provider" => provider_name}}) do
    Logger.info("CRM contact sync: targeted sync for user #{user_id}, provider #{provider_name}")

    providers = Application.get_env(:social_scribe, :crm_providers, [])

    case Enum.find(providers, &(&1.name == provider_name)) do
      nil ->
        Logger.warning("CRM contact sync: unknown provider #{provider_name}")
        :ok

      provider ->
        sync_user_provider(user_id, provider)
    end
  end

  def perform(%Oban.Job{args: _args}) do
    Logger.info("CRM contact sync: running cron sync for all providers...")

    providers = Application.get_env(:social_scribe, :crm_providers, [])

    Enum.each(providers, fn provider ->
      credentials = get_credentials_for_provider(provider.name)

      Enum.each(credentials, fn credential ->
        sync_user_provider(credential.user_id, provider)
      end)
    end)

    :ok
  end

  defp sync_user_provider(user_id, provider) do
    case get_credential(user_id, provider.name) do
      nil ->
        Logger.debug("CRM contact sync: no #{provider.name} credential for user #{user_id}")
        :ok

      credential ->
        case provider.behaviour_module.list_contacts(credential) do
          {:ok, contacts} ->
            CRM.upsert_contacts(user_id, provider.name, contacts)

            Logger.info(
              "CRM contact sync: synced #{length(contacts)} #{provider.name} contacts for user #{user_id}"
            )

            :ok

          {:error, reason} ->
            Logger.error(
              "CRM contact sync: failed for user #{user_id}, provider #{provider.name}: #{inspect(reason)}"
            )

            :ok
        end
    end
  end

  defp get_credentials_for_provider(provider_name) do
    from(c in UserCredential,
      where: c.provider == ^provider_name,
      where: not is_nil(c.token)
    )
    |> Repo.all()
  end

  defp get_credential(user_id, provider_name) do
    Repo.get_by(UserCredential, user_id: user_id, provider: provider_name)
  end
end
