defmodule SocialScribe.CrmTokenRefresherBehaviour do
  @moduledoc """
  Behaviour for CRM token refresher modules.
  """

  alias SocialScribe.Accounts.UserCredential

  @callback refresh_credential(credential :: %UserCredential{}) ::
              {:ok, %UserCredential{}} | {:error, any()}

  @callback ensure_valid_token(credential :: %UserCredential{}) ::
              {:ok, %UserCredential{}} | {:error, any()}
end
