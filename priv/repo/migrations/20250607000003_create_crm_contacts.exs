defmodule SocialScribe.Repo.Migrations.CreateCrmContacts do
  use Ecto.Migration

  def change do
    create table(:crm_contacts) do
      add :provider, :string, null: false
      add :provider_contact_id, :string, null: false
      add :first_name, :string
      add :last_name, :string
      add :email, :string
      add :company, :string
      add :job_title, :string
      add :display_name, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:crm_contacts, [:user_id, :provider, :provider_contact_id])
    create index(:crm_contacts, [:user_id])
  end
end
