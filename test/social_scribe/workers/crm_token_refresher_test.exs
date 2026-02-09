defmodule SocialScribe.Workers.CrmTokenRefresherTest do
  use SocialScribe.DataCase, async: true

  import Mox
  import SocialScribe.AccountsFixtures

  alias SocialScribe.Workers.CrmTokenRefresher
  alias SocialScribe.Accounts

  setup :verify_on_exit!

  setup do
    Application.put_env(:social_scribe, :crm_token_refreshers, %{
      "hubspot" => SocialScribe.HubspotTokenRefresherMock,
      "salesforce" => SocialScribe.SalesforceTokenRefresherMock
    })

    on_exit(fn ->
      Application.delete_env(:social_scribe, :crm_token_refreshers)
    end)

    :ok
  end

  describe "perform/1 with hubspot provider" do
    test "calls refresh_credential for expiring hubspot tokens" do
      user = user_fixture()

      credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
        })

      expect(SocialScribe.HubspotTokenRefresherMock, :refresh_credential, fn cred ->
        assert cred.id == credential.id
        {:ok, cred}
      end)

      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "hubspot"})
    end

    test "does not call refresh_credential when no hubspot tokens are expiring" do
      user = user_fixture()

      _credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 30, :minute)
        })

      # Mox verify_on_exit! will fail if refresh_credential is called unexpectedly
      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "hubspot"})
    end

    test "does nothing when no hubspot credentials exist" do
      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "hubspot"})
    end

    test "skips credentials without a refresh token" do
      user = user_fixture()

      {:ok, _credential} =
        Accounts.create_user_credential(%{
          user_id: user.id,
          provider: "hubspot",
          uid: "hub_#{System.unique_integer([:positive])}",
          token: "some_token",
          refresh_token: nil,
          expires_at: DateTime.add(DateTime.utc_now(), 5, :minute),
          email: "test@example.com"
        })

      # No refresh_token means the query excludes it, so no mock call expected
      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "hubspot"})
    end
  end

  describe "perform/1 with salesforce provider" do
    test "calls refresh_credential for expiring salesforce tokens" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
        })

      expect(SocialScribe.SalesforceTokenRefresherMock, :refresh_credential, fn cred ->
        assert cred.id == credential.id
        {:ok, cred}
      end)

      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "salesforce"})
    end

    test "does not call refresh_credential when no salesforce tokens are expiring" do
      user = user_fixture()

      _credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 30, :minute)
        })

      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "salesforce"})
    end
  end

  describe "perform/1 with invalid provider" do
    test "raises on unknown provider" do
      assert_raise KeyError, fn ->
        perform_job(CrmTokenRefresher, %{"provider" => "unknown_crm"})
      end
    end
  end

  describe "credential expiration threshold" do
    test "refreshes token expiring in 9 minutes (within threshold)" do
      user = user_fixture()

      credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 9, :minute)
        })

      expect(SocialScribe.HubspotTokenRefresherMock, :refresh_credential, fn cred ->
        assert cred.id == credential.id
        {:ok, cred}
      end)

      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "hubspot"})
    end

    test "does not refresh token expiring in 11 minutes (outside threshold)" do
      user = user_fixture()

      _credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 11, :minute)
        })

      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "hubspot"})
    end

    test "refreshes already-expired tokens" do
      user = user_fixture()

      credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), -5, :minute)
        })

      expect(SocialScribe.HubspotTokenRefresherMock, :refresh_credential, fn cred ->
        assert cred.id == credential.id
        {:ok, cred}
      end)

      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "hubspot"})
    end
  end

  describe "multiple credentials" do
    test "calls refresh_credential for each expiring credential" do
      user1 = user_fixture()
      user2 = user_fixture()

      cred1 =
        hubspot_credential_fixture(%{
          user_id: user1.id,
          expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
        })

      cred2 =
        hubspot_credential_fixture(%{
          user_id: user2.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3, :minute)
        })

      expected_ids = MapSet.new([cred1.id, cred2.id])

      expect(SocialScribe.HubspotTokenRefresherMock, :refresh_credential, 2, fn cred ->
        assert MapSet.member?(expected_ids, cred.id)
        {:ok, cred}
      end)

      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "hubspot"})
    end

    test "only refreshes credentials for the specified provider" do
      user = user_fixture()

      hs_cred =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
        })

      sf_cred =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
        })

      # Running hubspot refresh should only call the hubspot mock
      expect(SocialScribe.HubspotTokenRefresherMock, :refresh_credential, fn cred ->
        assert cred.id == hs_cred.id
        {:ok, cred}
      end)

      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "hubspot"})

      # Running salesforce refresh should only call the salesforce mock
      expect(SocialScribe.SalesforceTokenRefresherMock, :refresh_credential, fn cred ->
        assert cred.id == sf_cred.id
        {:ok, cred}
      end)

      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "salesforce"})
    end
  end

  describe "error handling" do
    test "logs error but returns :ok when refresh_credential fails" do
      user = user_fixture()

      _credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
        })

      expect(SocialScribe.HubspotTokenRefresherMock, :refresh_credential, fn _cred ->
        {:error, {401, %{"error" => "invalid_grant"}}}
      end)

      assert :ok = perform_job(CrmTokenRefresher, %{"provider" => "hubspot"})
    end
  end
end
