defmodule SocialScribe.SalesforceApi do
  @moduledoc """
  Salesforce CRM API client for contacts operations.
  Implements automatic token refresh on 401/expired token errors.
  """

  @behaviour SocialScribe.CrmApiBehaviour

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.SalesforceTokenRefresher

  require Logger

  @api_version "v59.0"

  @contact_fields [
    "Id",
    "FirstName",
    "LastName",
    "Email",
    "Phone",
    "MobilePhone",
    "Title",
    "Department",
    "MailingStreet",
    "MailingCity",
    "MailingState",
    "MailingPostalCode",
    "MailingCountry"
  ]

  defp client(access_token, instance_url) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "#{instance_url}/services/data/#{@api_version}"},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{access_token}"},
         {"Content-Type", "application/json"}
       ]}
    ])
  end

  defp get_instance_url(%UserCredential{metadata: %{"instance_url" => url}}) when is_binary(url),
    do: url

  defp get_instance_url(_), do: "https://login.salesforce.com"

  @doc """
  Searches for contacts by query string using SOSL.
  Returns up to 10 matching contacts.
  """
  def search_contacts(%UserCredential{} = credential, query) when is_binary(query) do
    with_token_refresh(credential, fn cred ->
      sanitized = sanitize_sosl(query)
      instance_url = get_instance_url(cred)

      sosl =
        "FIND {#{sanitized}} IN ALL FIELDS RETURNING Contact(#{Enum.join(@contact_fields, ",")}) LIMIT 10"

      url = "/search/?q=#{URI.encode(sosl)}"

      case Tesla.get(client(cred.token, instance_url), url) do
        {:ok, %Tesla.Env{status: 200, body: %{"searchRecords" => records}}} ->
          contacts = Enum.map(records, &format_contact/1)
          {:ok, contacts}

        {:ok, %Tesla.Env{status: 200, body: body}} when is_list(body) ->
          contacts = Enum.map(body, &format_contact/1)
          {:ok, contacts}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @doc """
  Gets a single contact by ID.
  """
  def get_contact(%UserCredential{} = credential, contact_id) do
    with_token_refresh(credential, fn cred ->
      instance_url = get_instance_url(cred)
      fields_param = Enum.join(@contact_fields, ",")
      url = "/sobjects/Contact/#{contact_id}?fields=#{fields_param}"

      case Tesla.get(client(cred.token, instance_url), url) do
        {:ok, %Tesla.Env{status: 200, body: body}} ->
          {:ok, format_contact(body)}

        {:ok, %Tesla.Env{status: 404, body: _body}} ->
          {:error, :not_found}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @doc """
  Updates a contact's fields.
  Salesforce PATCH returns 204 No Content on success.
  """
  def update_contact(%UserCredential{} = credential, contact_id, updates)
      when is_map(updates) do
    with_token_refresh(credential, fn cred ->
      instance_url = get_instance_url(cred)
      # Map our lowercase keys to Salesforce PascalCase
      sf_updates = to_salesforce_fields(updates)

      case Tesla.patch(
             client(cred.token, instance_url),
             "/sobjects/Contact/#{contact_id}",
             sf_updates
           ) do
        {:ok, %Tesla.Env{status: 204}} ->
          # Salesforce returns 204 No Content on success, fetch the updated contact
          # Use `cred` (the potentially-refreshed credential) instead of the outer
          # `credential` to avoid using a stale token for the follow-up GET.
          get_contact(cred, contact_id)

        {:ok, %Tesla.Env{status: 200, body: body}} ->
          {:ok, format_contact(body)}

        {:ok, %Tesla.Env{status: 404, body: _body}} ->
          {:error, :not_found}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @doc """
  Batch updates multiple fields on a contact.
  """
  def apply_updates(%UserCredential{} = credential, contact_id, updates_list)
      when is_list(updates_list) do
    updates_map =
      updates_list
      |> Enum.filter(fn update -> update[:apply] == true end)
      |> Enum.reduce(%{}, fn update, acc ->
        Map.put(acc, update.field, update.new_value)
      end)

    if map_size(updates_map) > 0 do
      update_contact(credential, contact_id, updates_map)
    else
      {:ok, :no_updates}
    end
  end

  @doc """
  Sanitizes a string for use in SOSL FIND clause.
  Escapes special characters that have meaning in SOSL.
  """
  def sanitize_sosl(query) do
    query
    |> String.replace(~r/[\\?&|!{}[\]()^~*:\"'+\-]/, " ")
    |> String.trim()
  end

  @doc """
  Creates a new contact in Salesforce with the given properties.
  Salesforce returns 201 with the new record ID on success.
  """
  def create_contact(%UserCredential{} = credential, properties) when is_map(properties) do
    with_token_refresh(credential, fn cred ->
      instance_url = get_instance_url(cred)
      sf_fields = to_salesforce_fields(properties)

      case Tesla.post(client(cred.token, instance_url), "/sobjects/Contact", sf_fields) do
        {:ok, %Tesla.Env{status: 201, body: %{"id" => id, "success" => true}}} ->
          get_contact(cred, id)

        {:ok, %Tesla.Env{status: 400, body: body}} ->
          {:error, {:validation_error, body}}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @doc """
  Lists contacts from Salesforce, up to 500 contacts ordered by last modified.
  Used for syncing contacts to the local CRM contacts table.
  """
  def list_contacts(%UserCredential{} = credential) do
    with_token_refresh(credential, fn cred ->
      instance_url = get_instance_url(cred)
      fields = Enum.join(@contact_fields, ",")
      soql = "SELECT #{fields} FROM Contact ORDER BY LastModifiedDate DESC LIMIT 500"
      url = "/query/?q=#{URI.encode(soql)}"

      case Tesla.get(client(cred.token, instance_url), url) do
        {:ok, %Tesla.Env{status: 200, body: %{"records" => records}}} ->
          contacts = records |> Enum.map(&format_contact/1) |> Enum.reject(&is_nil/1)
          {:ok, contacts}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @doc """
  Formats a Salesforce contact response into a normalized structure.
  """
  def format_contact(%{"Id" => id} = contact) do
    %{
      id: id,
      firstname: contact["FirstName"],
      lastname: contact["LastName"],
      email: contact["Email"],
      phone: contact["Phone"],
      mobilephone: contact["MobilePhone"],
      jobtitle: contact["Title"],
      department: contact["Department"],
      address: contact["MailingStreet"],
      city: contact["MailingCity"],
      state: contact["MailingState"],
      zip: contact["MailingPostalCode"],
      country: contact["MailingCountry"],
      display_name: format_display_name(contact)
    }
  end

  def format_contact(_), do: nil

  defp format_display_name(contact) do
    firstname = contact["FirstName"] || ""
    lastname = contact["LastName"] || ""
    email = contact["Email"] || ""

    name = String.trim("#{firstname} #{lastname}")

    if name == "" do
      email
    else
      name
    end
  end

  @field_to_salesforce %{
    "firstname" => "FirstName",
    "lastname" => "LastName",
    "email" => "Email",
    "phone" => "Phone",
    "mobilephone" => "MobilePhone",
    "jobtitle" => "Title",
    "department" => "Department",
    "address" => "MailingStreet",
    "city" => "MailingCity",
    "state" => "MailingState",
    "zip" => "MailingPostalCode",
    "country" => "MailingCountry"
  }

  defp to_salesforce_fields(updates) do
    Enum.reduce(updates, %{}, fn {key, value}, acc ->
      sf_key = Map.get(@field_to_salesforce, to_string(key), to_string(key))
      Map.put(acc, sf_key, value)
    end)
  end

  defp with_token_refresh(%UserCredential{} = credential, api_call) do
    with {:ok, credential} <- SalesforceTokenRefresher.ensure_valid_token(credential) do
      case api_call.(credential) do
        {:error, {:api_error, status, body}} when status in [401, 400] ->
          if is_token_error?(status, body) do
            Logger.info("Salesforce token expired, refreshing and retrying...")
            retry_with_fresh_token(credential, api_call)
          else
            Logger.error("Salesforce API error: #{status} - #{sanitize_log(body)}")
            {:error, {:api_error, status, body}}
          end

        other ->
          other
      end
    end
  end

  defp retry_with_fresh_token(credential, api_call) do
    case SalesforceTokenRefresher.refresh_credential(credential) do
      {:ok, refreshed_credential} ->
        case api_call.(refreshed_credential) do
          {:error, {:api_error, status, body}} ->
            Logger.error("Salesforce API error after refresh: #{status} - #{sanitize_log(body)}")
            {:error, {:api_error, status, body}}

          {:error, {:http_error, reason}} ->
            Logger.error("Salesforce HTTP error after refresh: #{sanitize_log(reason)}")
            {:error, {:http_error, reason}}

          success ->
            success
        end

      {:error, refresh_error} ->
        Logger.error("Failed to refresh Salesforce token: #{sanitize_log(refresh_error)}")
        {:error, {:token_refresh_failed, refresh_error}}
    end
  end

  defp sanitize_log(body) when is_map(body) do
    body
    |> Map.take(["error", "errorCode", "message", "error_description"])
    |> inspect()
  end

  defp sanitize_log(body) when is_list(body) do
    body
    |> Enum.map(fn
      item when is_map(item) -> Map.take(item, ["error", "errorCode", "message"])
      other -> other
    end)
    |> inspect()
  end

  defp sanitize_log(other), do: inspect(other)

  defp is_token_error?(401, _), do: true

  defp is_token_error?(_, body) when is_list(body) do
    Enum.any?(body, fn
      %{"errorCode" => code} -> code in ["INVALID_SESSION_ID", "INVALID_AUTH_HEADER"]
      _ -> false
    end)
  end

  defp is_token_error?(_, %{"error" => error}) do
    error in ["invalid_grant", "invalid_token", "expired_token"]
  end

  defp is_token_error?(_, _), do: false
end
