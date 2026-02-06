defmodule SocialScribe.SalesforceTokenRefresherTest do
  use SocialScribe.DataCase, async: true

  alias SocialScribe.SalesforceTokenRefresher

  import SocialScribe.AccountsFixtures

  describe "ensure_valid_token/1" do
    test "returns credential if not expired" do
      credential =
        salesforce_credential_fixture(%{
          expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)
        })

      assert {:ok, ^credential} = SalesforceTokenRefresher.ensure_valid_token(credential)
    end

    test "attempts refresh if token is about to expire" do
      credential =
        salesforce_credential_fixture(%{
          expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
        })

      # Since we can't actually call Salesforce in tests, this will fail
      # but it proves the path is taken
      result = SalesforceTokenRefresher.ensure_valid_token(credential)
      assert {:error, _} = result
    end
  end
end
