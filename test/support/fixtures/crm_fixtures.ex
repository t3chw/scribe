defmodule SocialScribe.CRMFixtures do
  @moduledoc """
  Test helpers for creating CRM contact entities.
  """

  alias SocialScribe.Repo
  alias SocialScribe.CRM.CRMContact

  import SocialScribe.AccountsFixtures

  def crm_contact_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id
    unique = System.unique_integer([:positive])

    contact_attrs =
      attrs
      |> Enum.into(%{
        user_id: user_id,
        provider: "hubspot",
        provider_contact_id: "contact_#{unique}",
        first_name: "First#{unique}",
        last_name: "Last#{unique}",
        email: "contact#{unique}@example.com",
        company: "Acme Corp",
        job_title: "Engineer",
        display_name: "First#{unique} Last#{unique}"
      })

    %CRMContact{}
    |> CRMContact.changeset(contact_attrs)
    |> Repo.insert!()
  end

  def sample_hubspot_contacts do
    [
      %{
        id: "hs_101",
        firstname: "Alice",
        lastname: "Johnson",
        email: "alice@hubspot-corp.com",
        company: "HubSpot Corp",
        jobtitle: "VP Sales",
        display_name: "Alice Johnson"
      },
      %{
        id: "hs_102",
        firstname: "Bob",
        lastname: "Smith",
        email: "bob@hubspot-corp.com",
        company: "HubSpot Corp",
        jobtitle: "Engineer",
        display_name: "Bob Smith"
      }
    ]
  end

  def sample_salesforce_contacts do
    [
      %{
        id: "sf_201",
        firstname: "Carol",
        lastname: "Williams",
        email: "carol@salesforce-org.com",
        company: nil,
        jobtitle: "Director",
        display_name: "Carol Williams"
      },
      %{
        id: "sf_202",
        firstname: "Dave",
        lastname: "Brown",
        email: "dave@salesforce-org.com",
        company: nil,
        jobtitle: "Manager",
        display_name: "Dave Brown"
      }
    ]
  end
end
