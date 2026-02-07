defmodule SocialScribe.CRM do
  @moduledoc """
  Context for managing synced CRM contacts used for @mention autocomplete.
  """

  import Ecto.Query

  alias SocialScribe.Repo
  alias SocialScribe.CRM.CRMContact

  @doc """
  Searches CRM contacts by display_name for a given user.
  Returns maps ready for the autocomplete dropdown.
  """
  def search_contacts(user_id, query, limit \\ 5) do
    sanitized = "%#{sanitize_like(query)}%"

    from(c in CRMContact,
      where: c.user_id == ^user_id,
      where: ilike(c.display_name, ^sanitized),
      order_by: c.display_name,
      limit: ^limit,
      select: %{
        name: c.display_name,
        source: c.provider,
        email: c.email,
        company: c.company
      }
    )
    |> Repo.all()
  end

  @doc """
  Bulk upserts CRM contacts for a user+provider, then removes stale contacts
  that are no longer present in the latest sync.
  """
  def upsert_contacts(user_id, provider, contacts) when is_list(contacts) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    entries =
      contacts
      |> Enum.reject(&is_nil(&1))
      |> Enum.map(fn contact ->
        %{
          user_id: user_id,
          provider: provider,
          provider_contact_id: to_string(contact.id),
          first_name: contact[:firstname],
          last_name: contact[:lastname],
          email: contact[:email],
          company: contact[:company],
          job_title: contact[:jobtitle],
          display_name: build_display_name(contact),
          inserted_at: now,
          updated_at: now
        }
      end)

    provider_contact_ids = Enum.map(entries, & &1.provider_contact_id)

    # Upsert in chunks of 100
    entries
    |> Enum.chunk_every(100)
    |> Enum.each(fn chunk ->
      Repo.insert_all(CRMContact, chunk,
        on_conflict:
          {:replace,
           [:first_name, :last_name, :email, :company, :job_title, :display_name, :updated_at]},
        conflict_target: [:user_id, :provider, :provider_contact_id]
      )
    end)

    # Delete stale contacts not in the latest batch
    if provider_contact_ids != [] do
      from(c in CRMContact,
        where: c.user_id == ^user_id,
        where: c.provider == ^provider,
        where: c.provider_contact_id not in ^provider_contact_ids
      )
      |> Repo.delete_all()
    end

    :ok
  end

  @doc """
  Deletes all CRM contacts for a user+provider (e.g. when disconnecting a CRM).
  """
  def delete_contacts_for_provider(user_id, provider) do
    from(c in CRMContact,
      where: c.user_id == ^user_id,
      where: c.provider == ^provider
    )
    |> Repo.delete_all()

    :ok
  end

  defp sanitize_like(query) do
    query
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  defp build_display_name(contact) do
    firstname = contact[:firstname] || ""
    lastname = contact[:lastname] || ""
    email = contact[:email] || ""

    name = String.trim("#{firstname} #{lastname}")

    if name == "" do
      if email == "", do: "Unknown", else: email
    else
      name
    end
  end
end
