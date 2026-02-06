defmodule SocialScribe.SalesforceApiTest do
  use SocialScribe.DataCase, async: true

  alias SocialScribe.SalesforceApi

  describe "format_contact/1" do
    test "formats a Salesforce contact with all fields" do
      raw = %{
        "Id" => "003abc123",
        "FirstName" => "Jane",
        "LastName" => "Smith",
        "Email" => "jane@example.com",
        "Phone" => "555-1234",
        "MobilePhone" => "555-5678",
        "Title" => "CTO",
        "Department" => "Engineering",
        "MailingStreet" => "123 Main St",
        "MailingCity" => "Denver",
        "MailingState" => "CO",
        "MailingPostalCode" => "80202",
        "MailingCountry" => "US"
      }

      result = SalesforceApi.format_contact(raw)

      assert result.id == "003abc123"
      assert result.firstname == "Jane"
      assert result.lastname == "Smith"
      assert result.email == "jane@example.com"
      assert result.phone == "555-1234"
      assert result.mobilephone == "555-5678"
      assert result.jobtitle == "CTO"
      assert result.department == "Engineering"
      assert result.address == "123 Main St"
      assert result.city == "Denver"
      assert result.state == "CO"
      assert result.zip == "80202"
      assert result.country == "US"
      assert result.display_name == "Jane Smith"
    end

    test "formats display_name with email fallback" do
      result =
        SalesforceApi.format_contact(%{
          "Id" => "003abc",
          "FirstName" => nil,
          "LastName" => nil,
          "Email" => "fallback@email.com",
          "Phone" => nil,
          "MobilePhone" => nil,
          "Title" => nil,
          "Department" => nil,
          "MailingStreet" => nil,
          "MailingCity" => nil,
          "MailingState" => nil,
          "MailingPostalCode" => nil,
          "MailingCountry" => nil
        })

      assert result.display_name == "fallback@email.com"
    end

    test "returns nil for invalid input" do
      assert SalesforceApi.format_contact(%{"foo" => "bar"}) == nil
    end
  end

  describe "sanitize_sosl/1" do
    test "escapes special SOSL characters" do
      assert SalesforceApi.sanitize_sosl("test?query") == "test query"
      assert SalesforceApi.sanitize_sosl("hello & world") == "hello   world"
      assert SalesforceApi.sanitize_sosl("normal text") == "normal text"
    end

    test "trims whitespace" do
      assert SalesforceApi.sanitize_sosl("  hello  ") == "hello"
    end
  end
end
