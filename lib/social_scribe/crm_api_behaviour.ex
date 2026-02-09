defmodule SocialScribe.CrmApiBehaviour do
  @moduledoc """
  Unified CRM API behaviour. Defines the contract all CRM API clients must implement.
  Use `impl/1` to get the implementation module for a given provider.

  To add a new CRM provider, implement these callbacks and register in config.
  """

  alias SocialScribe.Accounts.UserCredential

  @callback search_contacts(credential :: UserCredential.t(), query :: String.t()) ::
              {:ok, list(map())} | {:error, any()}

  @callback get_contact(credential :: UserCredential.t(), contact_id :: String.t()) ::
              {:ok, map()} | {:error, any()}

  @callback update_contact(
              credential :: UserCredential.t(),
              contact_id :: String.t(),
              updates :: map()
            ) ::
              {:ok, map()} | {:error, any()}

  @callback apply_updates(
              credential :: UserCredential.t(),
              contact_id :: String.t(),
              updates_list :: list(map())
            ) ::
              {:ok, map() | :no_updates} | {:error, any()}

  @callback list_contacts(credential :: UserCredential.t()) ::
              {:ok, list(map())} | {:error, any()}

  @callback create_contact(credential :: UserCredential.t(), properties :: map()) ::
              {:ok, map()} | {:error, any()}

  @doc """
  Returns the implementation module for the given CRM provider name.
  Raises if the provider name is not registered in ProviderConfig.
  """
  def impl(provider_name) when is_binary(provider_name) do
    provider = SocialScribe.CRM.ProviderConfig.get(provider_name)
    Application.get_env(:social_scribe, provider.api_config_key, provider.api_module)
  end
end
