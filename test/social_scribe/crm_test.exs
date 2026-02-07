defmodule SocialScribe.CRMTest do
  use SocialScribe.DataCase, async: true

  alias SocialScribe.CRM

  import SocialScribe.AccountsFixtures
  import SocialScribe.CRMFixtures

  describe "search_contacts/3" do
    test "returns matching contacts by display_name" do
      user = user_fixture()
      crm_contact_fixture(%{user_id: user.id, display_name: "Alice Johnson", provider: "hubspot"})
      crm_contact_fixture(%{user_id: user.id, display_name: "Bob Smith", provider: "hubspot"})

      results = CRM.search_contacts(user.id, "Alice")
      assert length(results) == 1
      assert hd(results).name == "Alice Johnson"
      assert hd(results).source == "hubspot"
    end

    test "returns empty list when no match" do
      user = user_fixture()
      crm_contact_fixture(%{user_id: user.id, display_name: "Alice Johnson"})

      assert CRM.search_contacts(user.id, "Zzzzz") == []
    end

    test "respects limit" do
      user = user_fixture()

      for i <- 1..10 do
        crm_contact_fixture(%{
          user_id: user.id,
          display_name: "Contact #{i}",
          provider: "hubspot"
        })
      end

      results = CRM.search_contacts(user.id, "Contact", 3)
      assert length(results) == 3
    end

    test "scoped to user" do
      user1 = user_fixture()
      user2 = user_fixture()
      crm_contact_fixture(%{user_id: user1.id, display_name: "Alice Johnson"})
      crm_contact_fixture(%{user_id: user2.id, display_name: "Alice Williams"})

      results = CRM.search_contacts(user1.id, "Alice")
      assert length(results) == 1
      assert hd(results).name == "Alice Johnson"
    end

    test "case-insensitive search" do
      user = user_fixture()
      crm_contact_fixture(%{user_id: user.id, display_name: "Alice Johnson"})

      assert length(CRM.search_contacts(user.id, "alice")) == 1
      assert length(CRM.search_contacts(user.id, "ALICE")) == 1
    end
  end

  describe "upsert_contacts/3" do
    test "inserts new contacts" do
      user = user_fixture()

      contacts = [
        %{
          id: "hs_1",
          firstname: "Alice",
          lastname: "Johnson",
          email: "alice@test.com",
          company: "Acme",
          jobtitle: "VP"
        },
        %{
          id: "hs_2",
          firstname: "Bob",
          lastname: "Smith",
          email: "bob@test.com",
          company: "Acme",
          jobtitle: "Eng"
        }
      ]

      assert :ok = CRM.upsert_contacts(user.id, "hubspot", contacts)

      results = CRM.search_contacts(user.id, "Alice")
      assert length(results) == 1
      assert hd(results).name == "Alice Johnson"

      results = CRM.search_contacts(user.id, "Bob")
      assert length(results) == 1
    end

    test "updates existing contacts on re-sync" do
      user = user_fixture()

      contacts_v1 = [
        %{
          id: "hs_1",
          firstname: "Alice",
          lastname: "Johnson",
          email: "alice@old.com",
          company: "OldCo",
          jobtitle: "VP"
        }
      ]

      contacts_v2 = [
        %{
          id: "hs_1",
          firstname: "Alice",
          lastname: "Updated",
          email: "alice@new.com",
          company: "NewCo",
          jobtitle: "CEO"
        }
      ]

      CRM.upsert_contacts(user.id, "hubspot", contacts_v1)
      CRM.upsert_contacts(user.id, "hubspot", contacts_v2)

      results = CRM.search_contacts(user.id, "Alice")
      assert length(results) == 1
      assert hd(results).name == "Alice Updated"
      assert hd(results).email == "alice@new.com"
    end

    test "removes stale contacts not in latest batch" do
      user = user_fixture()

      contacts_v1 = [
        %{
          id: "hs_1",
          firstname: "Alice",
          lastname: "Johnson",
          email: "a@t.com",
          company: nil,
          jobtitle: nil
        },
        %{
          id: "hs_2",
          firstname: "Bob",
          lastname: "Smith",
          email: "b@t.com",
          company: nil,
          jobtitle: nil
        }
      ]

      contacts_v2 = [
        %{
          id: "hs_1",
          firstname: "Alice",
          lastname: "Johnson",
          email: "a@t.com",
          company: nil,
          jobtitle: nil
        }
      ]

      CRM.upsert_contacts(user.id, "hubspot", contacts_v1)
      assert length(CRM.search_contacts(user.id, "", 10)) == 2

      CRM.upsert_contacts(user.id, "hubspot", contacts_v2)
      all = CRM.search_contacts(user.id, "", 10)
      assert length(all) == 1
      assert hd(all).name == "Alice Johnson"
    end
  end

  describe "delete_contacts_for_provider/2" do
    test "removes only that provider's contacts" do
      user = user_fixture()
      crm_contact_fixture(%{user_id: user.id, display_name: "HS Contact", provider: "hubspot"})
      crm_contact_fixture(%{user_id: user.id, display_name: "SF Contact", provider: "salesforce"})

      CRM.delete_contacts_for_provider(user.id, "hubspot")

      assert CRM.search_contacts(user.id, "HS") == []
      assert length(CRM.search_contacts(user.id, "SF")) == 1
    end
  end
end
