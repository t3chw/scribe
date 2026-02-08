defmodule SocialScribe.SalesforceSuggestionsTest do
  use SocialScribe.DataCase, async: true

  alias SocialScribe.CrmSuggestions

  describe "merge_with_contact/2" do
    test "merges suggestions with contact data and filters unchanged" do
      contact = %{
        firstname: "Jane",
        lastname: "Smith",
        email: "jane@old.com",
        phone: "555-1234"
      }

      suggestions = [
        %{
          field: "email",
          label: "Email",
          current_value: nil,
          new_value: "jane@new.com",
          context: "mentioned in meeting",
          apply: true,
          has_change: true
        },
        %{
          field: "phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-1234",
          context: "same phone",
          apply: true,
          has_change: true
        }
      ]

      result = CrmSuggestions.merge_with_contact(suggestions, contact)

      # email changed, phone didn't
      assert length(result) == 1
      [email_suggestion] = result
      assert email_suggestion.field == "email"
      assert email_suggestion.current_value == "jane@old.com"
      assert email_suggestion.new_value == "jane@new.com"
      assert email_suggestion.apply == true
    end

    test "returns empty list when all values match" do
      contact = %{email: "same@example.com"}

      suggestions = [
        %{
          field: "email",
          label: "Email",
          current_value: nil,
          new_value: "same@example.com",
          context: "test",
          apply: true,
          has_change: true
        }
      ]

      result = CrmSuggestions.merge_with_contact(suggestions, contact)
      assert result == []
    end
  end
end
