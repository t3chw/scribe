defmodule SocialScribe.SalesforceApiPropertyTest do
  use SocialScribe.DataCase, async: true
  use ExUnitProperties

  import SocialScribe.AccountsFixtures

  @salesforce_fields [
    "firstname",
    "lastname",
    "email",
    "phone",
    "mobilephone",
    "jobtitle",
    "department",
    "address",
    "city",
    "state",
    "zip",
    "country"
  ]

  # SOSL special characters that sanitize_sosl should remove
  @sosl_special_chars String.graphemes("\\?&|!{}[]()^~*:\"'+\-")

  describe "apply_updates/3 properties" do
    setup do
      user = user_fixture()
      credential = salesforce_credential_fixture(%{user_id: user.id})
      %{credential: credential}
    end

    property "returns {:ok, :no_updates} when all updates have apply: false", %{
      credential: credential
    } do
      check all(updates <- list_of(update_generator(apply: false), min_length: 1, max_length: 10)) do
        result = SocialScribe.SalesforceApi.apply_updates(credential, "003ABC123", updates)
        assert result == {:ok, :no_updates}
      end
    end

    property "returns {:ok, :no_updates} for empty updates list", %{credential: credential} do
      check all(contact_id <- string(:alphanumeric, min_length: 1, max_length: 20)) do
        result = SocialScribe.SalesforceApi.apply_updates(credential, contact_id, [])
        assert result == {:ok, :no_updates}
      end
    end
  end

  describe "build_updates_map/1 logic properties" do
    property "filtering and mapping only includes apply: true fields" do
      check all(updates <- list_of(update_generator(), min_length: 1, max_length: 10)) do
        updates_map =
          updates
          |> Enum.filter(fn update -> update[:apply] == true end)
          |> Enum.reduce(%{}, fn update, acc ->
            Map.put(acc, update.field, update.new_value)
          end)

        applied_fields =
          updates
          |> Enum.filter(& &1[:apply])
          |> Enum.map(& &1.field)
          |> MapSet.new()

        for {field, _value} <- updates_map do
          assert MapSet.member?(applied_fields, field),
                 "Field #{field} should only be in map if apply was true"
        end
      end
    end

    property "map values match new_value from the last update for each field" do
      check all(updates <- list_of(update_generator(), min_length: 1, max_length: 10)) do
        updates_map =
          updates
          |> Enum.filter(fn update -> update[:apply] == true end)
          |> Enum.reduce(%{}, fn update, acc ->
            Map.put(acc, update.field, update.new_value)
          end)

        for {field, value} <- updates_map do
          matching_updates =
            updates
            |> Enum.filter(&(&1[:apply] && &1.field == field))

          assert Enum.any?(matching_updates, &(&1.new_value == value)),
                 "Value #{inspect(value)} for #{field} should come from an applied update"
        end
      end
    end

    property "map size is at most the number of unique applied fields" do
      check all(updates <- list_of(update_generator(), min_length: 0, max_length: 10)) do
        updates_map =
          updates
          |> Enum.filter(fn update -> update[:apply] == true end)
          |> Enum.reduce(%{}, fn update, acc ->
            Map.put(acc, update.field, update.new_value)
          end)

        unique_applied_fields =
          updates
          |> Enum.filter(& &1[:apply])
          |> Enum.map(& &1.field)
          |> Enum.uniq()
          |> length()

        assert map_size(updates_map) <= unique_applied_fields
      end
    end
  end

  describe "sanitize_sosl/1 properties" do
    property "output never contains SOSL special characters" do
      check all(input <- string(:printable, min_length: 0, max_length: 100)) do
        result = SocialScribe.SalesforceApi.sanitize_sosl(input)

        for char <- @sosl_special_chars do
          refute String.contains?(result, char),
                 "sanitize_sosl output should not contain #{inspect(char)}, got: #{inspect(result)}"
        end
      end
    end

    property "output has no leading/trailing whitespace" do
      check all(input <- string(:printable, min_length: 0, max_length: 100)) do
        result = SocialScribe.SalesforceApi.sanitize_sosl(input)
        assert result == String.trim(result)
      end
    end

    property "plain alphanumeric input passes through unchanged" do
      check all(input <- string(:alphanumeric, min_length: 1, max_length: 50)) do
        result = SocialScribe.SalesforceApi.sanitize_sosl(input)
        assert result == input
      end
    end
  end

  describe "format_contact/1 properties" do
    property "returns nil when map lacks Id key" do
      check all(
              firstname <- string(:alphanumeric, min_length: 1, max_length: 20),
              lastname <- string(:alphanumeric, min_length: 1, max_length: 20)
            ) do
        contact_without_id = %{
          "FirstName" => firstname,
          "LastName" => lastname,
          "Email" => "test@example.com"
        }

        assert SocialScribe.SalesforceApi.format_contact(contact_without_id) == nil
      end
    end
  end

  # Generators

  defp update_generator(opts \\ []) do
    apply_value = Keyword.get(opts, :apply, :random)

    gen all(
          field <- member_of(@salesforce_fields),
          new_value <- string(:alphanumeric, min_length: 1, max_length: 50),
          apply? <- if(apply_value == :random, do: boolean(), else: constant(apply_value))
        ) do
      %{field: field, new_value: new_value, apply: apply?}
    end
  end
end
