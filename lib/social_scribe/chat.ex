defmodule SocialScribe.Chat do
  @moduledoc """
  The Chat context for managing conversations and messages.
  """

  import Ecto.Query, warn: false
  alias SocialScribe.Repo
  alias SocialScribe.Chat.{Conversation, Message}

  def list_conversations(user_id) do
    from(c in Conversation,
      where: c.user_id == ^user_id,
      order_by: [desc: c.updated_at],
      preload: []
    )
    |> Repo.all()
  end

  def get_conversation!(id) do
    Repo.get!(Conversation, id)
  end

  @doc """
  Gets a conversation by ID, scoped to the given user.
  Raises Ecto.NoResultsError if not found or not owned by the user.
  """
  def get_conversation!(id, user_id) do
    from(c in Conversation, where: c.id == ^id and c.user_id == ^user_id)
    |> Repo.one!()
  end

  def get_conversation_with_messages(id) do
    Conversation
    |> Repo.get!(id)
    |> Repo.preload(messages: from(m in Message, order_by: [asc: m.inserted_at]))
  end

  @doc """
  Gets a conversation with messages, scoped to the given user.
  Raises Ecto.NoResultsError if not found or not owned by the user.
  """
  def get_conversation_with_messages(id, user_id) do
    from(c in Conversation, where: c.id == ^id and c.user_id == ^user_id)
    |> Repo.one!()
    |> Repo.preload(messages: from(m in Message, order_by: [asc: m.inserted_at]))
  end

  def create_conversation(attrs \\ %{}) do
    %Conversation{}
    |> Conversation.changeset(attrs)
    |> Repo.insert()
  end

  def add_message(conversation_id, attrs) do
    attrs = Map.put(attrs, :conversation_id, conversation_id)

    %Message{}
    |> Message.changeset(Map.new(attrs))
    |> Repo.insert()
  end

  def delete_conversation(%Conversation{} = conversation) do
    Repo.delete(conversation)
  end
end
