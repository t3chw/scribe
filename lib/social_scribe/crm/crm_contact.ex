defmodule SocialScribe.CRM.CRMContact do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:provider, :provider_contact_id, :display_name, :user_id]
  @optional_fields [:first_name, :last_name, :email, :company, :job_title]

  schema "crm_contacts" do
    field :provider, :string
    field :provider_contact_id, :string
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    field :company, :string
    field :job_title, :string
    field :display_name, :string

    belongs_to :user, SocialScribe.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(crm_contact, attrs) do
    crm_contact
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:user_id, :provider, :provider_contact_id])
  end
end
