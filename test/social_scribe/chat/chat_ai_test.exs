defmodule SocialScribe.Chat.ChatAITest do
  use SocialScribe.DataCase, async: true

  alias SocialScribe.Chat.ChatAI

  describe "extract_mentions/1" do
    test "extracts single name mentions" do
      assert ChatAI.extract_mentions("What about @John?") == ["John"]
    end

    test "extracts first and last name mentions" do
      assert ChatAI.extract_mentions("Tell me about @John Smith") == ["John Smith"]
    end

    test "extracts multiple mentions" do
      result = ChatAI.extract_mentions("Compare @Jane Doe and @Bob Wilson")
      assert "Jane Doe" in result
      assert "Bob Wilson" in result
    end

    test "returns empty list for no mentions" do
      assert ChatAI.extract_mentions("hello world") == []
    end

    test "deduplicates mentions" do
      result = ChatAI.extract_mentions("@John said hi, @John said bye")
      assert result == ["John"]
    end

    test "ignores lowercase after @" do
      assert ChatAI.extract_mentions("email me @john") == []
    end
  end

  describe "get_user_crm_credentials/1" do
    import SocialScribe.AccountsFixtures

    test "returns empty list when no CRM credentials" do
      user = user_fixture()
      assert ChatAI.get_user_crm_credentials(user.id) == []
    end

    test "returns hubspot credential when connected" do
      user = user_fixture()
      _cred = hubspot_credential_fixture(%{user_id: user.id})

      result = ChatAI.get_user_crm_credentials(user.id)
      assert length(result) == 1
      [{type, _cred}] = result
      assert type == :hubspot
    end

    test "returns salesforce credential when connected" do
      user = user_fixture()
      _cred = salesforce_credential_fixture(%{user_id: user.id})

      result = ChatAI.get_user_crm_credentials(user.id)
      assert length(result) == 1
      [{type, _cred}] = result
      assert type == :salesforce
    end

    test "returns both credentials when both connected" do
      user = user_fixture()
      _hub = hubspot_credential_fixture(%{user_id: user.id})
      _sf = salesforce_credential_fixture(%{user_id: user.id})

      result = ChatAI.get_user_crm_credentials(user.id)
      assert length(result) == 2
      types = Enum.map(result, fn {type, _} -> type end)
      assert :hubspot in types
      assert :salesforce in types
    end
  end
end
