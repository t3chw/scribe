defmodule SocialScribe.Chat.ChatAITest do
  use SocialScribe.DataCase, async: true

  import Mox

  alias SocialScribe.Chat.ChatAI

  setup :verify_on_exit!

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

    test "extracts capitalized names as fallback when no @ mentions" do
      result = ChatAI.extract_mentions("What is Anita's email?")
      assert "Anita" in result
    end

    test "extracts full names as fallback" do
      result = ChatAI.extract_mentions("Tell me about John Smith")
      assert "John Smith" in result
    end

    test "ignores common English words in fallback" do
      result = ChatAI.extract_mentions("What is the email?")
      assert result == []
    end

    test "prefers @ mentions over fallback" do
      result = ChatAI.extract_mentions("What about @John?")
      assert result == ["John"]
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

  describe "fetch_relevant_meetings/2" do
    import SocialScribe.AccountsFixtures
    import SocialScribe.MeetingsFixtures
    import SocialScribe.CalendarFixtures
    import SocialScribe.BotsFixtures

    test "returns empty context when no mentions" do
      user = user_fixture()
      assert {"", []} = ChatAI.fetch_relevant_meetings([], user.id)
    end

    test "returns empty context when no meetings exist" do
      user = user_fixture()
      assert {context, sources} = ChatAI.fetch_relevant_meetings(["Tim"], user.id)
      assert context == ""
      assert sources == []
    end

    test "returns meeting context when participant name matches mention" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      recall_bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id, user_id: user.id})

      meeting =
        meeting_fixture(%{
          calendar_event_id: calendar_event.id,
          recall_bot_id: recall_bot.id,
          title: "Team Sync"
        })

      _transcript =
        meeting_transcript_fixture(%{
          meeting_id: meeting.id,
          content: %{
            "data" => [
              %{
                "speaker" => "Tim Cook",
                "words" => [%{"text" => "Hello everyone", "start_timestamp" => 0.5}]
              }
            ]
          }
        })

      _participant =
        meeting_participant_fixture(%{meeting_id: meeting.id, name: "Tim Cook", is_host: false})

      {context, sources} = ChatAI.fetch_relevant_meetings(["Tim"], user.id)

      assert context =~ "Team Sync"
      assert length(sources) == 1
      assert hd(sources)["type"] == "meeting"
      assert hd(sources)["title"] == "Team Sync"
      assert hd(sources)["meeting_id"] == meeting.id
    end

    test "returns empty context when no participant matches" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      recall_bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id, user_id: user.id})

      meeting =
        meeting_fixture(%{
          calendar_event_id: calendar_event.id,
          recall_bot_id: recall_bot.id,
          title: "Team Sync"
        })

      _participant =
        meeting_participant_fixture(%{
          meeting_id: meeting.id,
          name: "Alice Johnson",
          is_host: true
        })

      {context, sources} = ChatAI.fetch_relevant_meetings(["Tim"], user.id)

      assert context == ""
      assert sources == []
    end

    test "limits to 5 most recent meetings" do
      user = user_fixture()

      # Create 6 meetings with matching participants
      meetings =
        for i <- 1..6 do
          calendar_event = calendar_event_fixture(%{user_id: user.id})

          recall_bot =
            recall_bot_fixture(%{calendar_event_id: calendar_event.id, user_id: user.id})

          meeting =
            meeting_fixture(%{
              calendar_event_id: calendar_event.id,
              recall_bot_id: recall_bot.id,
              title: "Meeting #{i}",
              recorded_at: DateTime.add(~U[2025-01-01 00:00:00Z], i * 86400, :second)
            })

          _transcript =
            meeting_transcript_fixture(%{
              meeting_id: meeting.id,
              content: %{
                "data" => [
                  %{
                    "speaker" => "Tim",
                    "words" => [%{"text" => "Hello", "start_timestamp" => 0.5}]
                  }
                ]
              }
            })

          _participant =
            meeting_participant_fixture(%{
              meeting_id: meeting.id,
              name: "Tim Cook",
              is_host: false
            })

          meeting
        end

      {_context, sources} = ChatAI.fetch_relevant_meetings(["Tim"], user.id)

      assert length(sources) == 5
      # Should be the 5 most recent (meetings are ordered desc by recorded_at)
      source_ids = Enum.map(sources, & &1["meeting_id"])
      # Meeting 6 (most recent) should be first
      most_recent = Enum.at(meetings, 5)
      assert most_recent.id in source_ids
    end
  end

  describe "process_message/3" do
    import SocialScribe.AccountsFixtures
    import SocialScribe.MeetingsFixtures
    import SocialScribe.CalendarFixtures
    import SocialScribe.BotsFixtures

    test "returns AI response with sources metadata" do
      user = user_fixture()
      _hub = hubspot_credential_fixture(%{user_id: user.id})

      SocialScribe.HubspotApiMock
      |> expect(:search_contacts, fn _cred, "Tim" ->
        {:ok,
         [
           %{
             email: "tim@example.com",
             display_name: "Tim Cook",
             first_name: "Tim",
             last_name: "Cook"
           }
         ]}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:chat_completion, fn _messages ->
        {:ok, "Tim Cook's email is tim@example.com"}
      end)

      assert {:ok, result} = ChatAI.process_message("What is @Tim's email?", user.id)
      assert result.content == "Tim Cook's email is tim@example.com"
      assert is_list(result.metadata["sources"])
      assert "Tim" in result.metadata["mentions"]

      crm_sources =
        Enum.filter(result.metadata["sources"], fn s -> Map.has_key?(s, "crm") end)

      assert length(crm_sources) >= 1
      assert hd(crm_sources)["crm"] == "hubspot"
    end

    test "includes meeting sources when participant matches" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      recall_bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id, user_id: user.id})

      meeting =
        meeting_fixture(%{
          calendar_event_id: calendar_event.id,
          recall_bot_id: recall_bot.id,
          title: "Quarterly Review"
        })

      _transcript =
        meeting_transcript_fixture(%{
          meeting_id: meeting.id,
          content: %{
            "data" => [
              %{
                "speaker" => "Tim Cook",
                "words" => [
                  %{"text" => "Revenue is up 20%", "start_timestamp" => 0.5}
                ]
              }
            ]
          }
        })

      _participant =
        meeting_participant_fixture(%{meeting_id: meeting.id, name: "Tim Cook", is_host: false})

      SocialScribe.AIContentGeneratorMock
      |> expect(:chat_completion, fn messages ->
        system_msg = hd(messages)
        assert system_msg.content =~ "meeting transcript data"
        assert system_msg.content =~ "Quarterly Review"
        {:ok, "In the Quarterly Review meeting, Tim mentioned revenue is up 20%."}
      end)

      assert {:ok, result} = ChatAI.process_message("What did @Tim say about revenue?", user.id)

      meeting_sources =
        Enum.filter(result.metadata["sources"], fn s -> s["type"] == "meeting" end)

      assert length(meeting_sources) == 1
      assert hd(meeting_sources)["title"] == "Quarterly Review"
    end

    test "returns only CRM sources when no meetings match" do
      user = user_fixture()
      _hub = hubspot_credential_fixture(%{user_id: user.id})

      SocialScribe.HubspotApiMock
      |> expect(:search_contacts, fn _cred, "Tim" ->
        {:ok,
         [
           %{
             email: "tim@example.com",
             display_name: "Tim Cook",
             first_name: "Tim",
             last_name: "Cook"
           }
         ]}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:chat_completion, fn _messages ->
        {:ok, "Tim Cook works at Apple."}
      end)

      assert {:ok, result} = ChatAI.process_message("Tell me about @Tim", user.id)

      meeting_sources =
        Enum.filter(result.metadata["sources"], fn s -> s["type"] == "meeting" end)

      assert meeting_sources == []
    end

    test "handles AI error gracefully" do
      user = user_fixture()

      SocialScribe.AIContentGeneratorMock
      |> expect(:chat_completion, fn _messages ->
        {:error, "API timeout"}
      end)

      assert {:error, "API timeout"} =
               ChatAI.process_message("Hello", user.id)
    end

    test "works with no mentions and no CRM credentials" do
      user = user_fixture()

      SocialScribe.AIContentGeneratorMock
      |> expect(:chat_completion, fn _messages ->
        {:ok,
         "I can help you with your meetings and CRM data. Try using @Name to look up a contact."}
      end)

      assert {:ok, result} = ChatAI.process_message("hello", user.id)
      assert result.metadata["sources"] == []
      assert result.metadata["mentions"] == []
    end
  end
end
