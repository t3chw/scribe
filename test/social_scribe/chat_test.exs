defmodule SocialScribe.ChatTest do
  use SocialScribe.DataCase, async: true

  alias SocialScribe.Chat

  import SocialScribe.AccountsFixtures

  describe "conversations" do
    test "create_conversation/1 creates a conversation" do
      user = user_fixture()
      assert {:ok, conversation} = Chat.create_conversation(%{user_id: user.id, title: "Test"})
      assert conversation.title == "Test"
      assert conversation.user_id == user.id
    end

    test "list_conversations/1 returns conversations for user" do
      user = user_fixture()
      {:ok, _c1} = Chat.create_conversation(%{user_id: user.id, title: "First"})
      {:ok, _c2} = Chat.create_conversation(%{user_id: user.id, title: "Second"})

      conversations = Chat.list_conversations(user.id)
      assert length(conversations) == 2
    end

    test "list_conversations/1 only returns user's conversations" do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, _c1} = Chat.create_conversation(%{user_id: user1.id, title: "User1"})
      {:ok, _c2} = Chat.create_conversation(%{user_id: user2.id, title: "User2"})

      assert length(Chat.list_conversations(user1.id)) == 1
      assert length(Chat.list_conversations(user2.id)) == 1
    end

    test "get_conversation_with_messages/1 preloads messages" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      {:ok, _msg} =
        Chat.add_message(conversation.id, %{
          role: "user",
          content: "Hello",
          metadata: %{}
        })

      loaded = Chat.get_conversation_with_messages(conversation.id)
      assert length(loaded.messages) == 1
      assert hd(loaded.messages).content == "Hello"
    end

    test "delete_conversation/1 deletes conversation and messages" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      {:ok, _msg} =
        Chat.add_message(conversation.id, %{
          role: "user",
          content: "Test",
          metadata: %{}
        })

      assert {:ok, _} = Chat.delete_conversation(conversation)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_conversation!(conversation.id) end
    end
  end

  describe "messages" do
    test "add_message/2 creates a message" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      assert {:ok, message} =
               Chat.add_message(conversation.id, %{
                 role: "user",
                 content: "What is @John's email?",
                 metadata: %{"mentions" => ["John"]}
               })

      assert message.role == "user"
      assert message.content == "What is @John's email?"
      assert message.metadata == %{"mentions" => ["John"]}
    end

    test "add_message/2 validates role" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      assert {:error, changeset} =
               Chat.add_message(conversation.id, %{
                 role: "invalid",
                 content: "Test",
                 metadata: %{}
               })

      assert %{role: ["is invalid"]} = errors_on(changeset)
    end

    test "messages are ordered by insertion time" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      {:ok, _} =
        Chat.add_message(conversation.id, %{role: "user", content: "First", metadata: %{}})

      {:ok, _} =
        Chat.add_message(conversation.id, %{role: "assistant", content: "Second", metadata: %{}})

      {:ok, _} =
        Chat.add_message(conversation.id, %{role: "user", content: "Third", metadata: %{}})

      loaded = Chat.get_conversation_with_messages(conversation.id)
      contents = Enum.map(loaded.messages, & &1.content)
      assert contents == ["First", "Second", "Third"]
    end
  end
end
