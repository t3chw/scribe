defmodule SocialScribe.Workers.CRMContactSyncerTest do
  use SocialScribe.DataCase, async: true

  import Mox
  import SocialScribe.AccountsFixtures
  import SocialScribe.CRMFixtures

  alias SocialScribe.Workers.CRMContactSyncer
  alias SocialScribe.CRM

  setup :verify_on_exit!

  describe "targeted sync (user_id + provider)" do
    test "syncs HubSpot contacts for a specific user" do
      user = user_fixture()
      _credential = hubspot_credential_fixture(%{user_id: user.id})

      SocialScribe.HubspotApiMock
      |> expect(:list_contacts, fn _credential ->
        {:ok, sample_hubspot_contacts()}
      end)

      assert :ok =
               perform_job(CRMContactSyncer, %{
                 "user_id" => user.id,
                 "provider" => "hubspot"
               })

      results = CRM.search_contacts(user.id, "Alice")
      assert length(results) == 1
      assert hd(results).name == "Alice Johnson"
      assert hd(results).source == "hubspot"
    end

    test "syncs Salesforce contacts for a specific user" do
      user = user_fixture()
      _credential = salesforce_credential_fixture(%{user_id: user.id})

      SocialScribe.SalesforceApiMock
      |> expect(:list_contacts, fn _credential ->
        {:ok, sample_salesforce_contacts()}
      end)

      assert :ok =
               perform_job(CRMContactSyncer, %{
                 "user_id" => user.id,
                 "provider" => "salesforce"
               })

      results = CRM.search_contacts(user.id, "Carol")
      assert length(results) == 1
      assert hd(results).name == "Carol Williams"
      assert hd(results).source == "salesforce"
    end

    test "handles API errors gracefully" do
      user = user_fixture()
      _credential = hubspot_credential_fixture(%{user_id: user.id})

      SocialScribe.HubspotApiMock
      |> expect(:list_contacts, fn _credential ->
        {:error, {:api_error, 500, "Internal Server Error"}}
      end)

      assert :ok =
               perform_job(CRMContactSyncer, %{
                 "user_id" => user.id,
                 "provider" => "hubspot"
               })

      # No contacts should be created
      assert CRM.search_contacts(user.id, "", 10) == []
    end

    test "handles unknown provider gracefully" do
      user = user_fixture()

      assert :ok =
               perform_job(CRMContactSyncer, %{
                 "user_id" => user.id,
                 "provider" => "unknown_crm"
               })
    end
  end

  describe "cron sync (no targeted args)" do
    test "syncs multiple providers for users with credentials" do
      user = user_fixture()
      _hs_cred = hubspot_credential_fixture(%{user_id: user.id})
      _sf_cred = salesforce_credential_fixture(%{user_id: user.id})

      SocialScribe.HubspotApiMock
      |> expect(:list_contacts, fn _credential ->
        {:ok, sample_hubspot_contacts()}
      end)

      SocialScribe.SalesforceApiMock
      |> expect(:list_contacts, fn _credential ->
        {:ok, sample_salesforce_contacts()}
      end)

      assert :ok = perform_job(CRMContactSyncer, %{})

      hs_results = CRM.search_contacts(user.id, "Alice")
      assert length(hs_results) == 1

      sf_results = CRM.search_contacts(user.id, "Carol")
      assert length(sf_results) == 1
    end
  end
end
