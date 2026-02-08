defmodule SocialScribeWeb.SalesforceModalMoxTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import Mox

  setup :verify_on_exit!

  describe "Salesforce Modal with mocked API" do
    setup %{conn: conn} do
      user = user_fixture()
      salesforce_credential = salesforce_credential_fixture(%{user_id: user.id})
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        salesforce_credential: salesforce_credential
      }
    end

    test "search_contacts returns mocked results", %{conn: conn, meeting: meeting} do
      mock_contacts = [
        %{
          id: "003abc",
          firstname: "Jane",
          lastname: "Smith",
          email: "jane@example.com",
          phone: "555-9999",
          mobilephone: nil,
          jobtitle: "CTO",
          department: "Engineering",
          address: nil,
          city: nil,
          state: nil,
          zip: nil,
          country: nil,
          display_name: "Jane Smith"
        }
      ]

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, query ->
        assert query == "Jane"
        {:ok, mock_contacts}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Jane"})

      :timer.sleep(200)

      html = render(view)

      assert html =~ "Jane Smith"
      assert html =~ "jane@example.com"
    end

    test "search_contacts handles API error gracefully", %{conn: conn, meeting: meeting} do
      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query ->
        {:error, {:api_error, 500, %{"message" => "Internal server error"}}}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Test"})

      :timer.sleep(200)

      html = render(view)

      assert html =~ "Failed to search contacts"
    end

    test "selecting contact triggers suggestion generation", %{conn: conn, meeting: meeting} do
      mock_contact = %{
        id: "003abc",
        firstname: "Jane",
        lastname: "Smith",
        email: "jane@example.com",
        phone: nil,
        mobilephone: nil,
        jobtitle: nil,
        department: nil,
        address: nil,
        city: nil,
        state: nil,
        zip: nil,
        country: nil,
        display_name: "Jane Smith"
      }

      mock_suggestions = [
        %{
          field: "phone",
          value: "555-9999",
          context: "Mentioned phone number"
        }
      ]

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query ->
        {:ok, [mock_contact]}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _meeting, _contact_name ->
        {:ok, mock_suggestions}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Jane"})

      :timer.sleep(200)

      view
      |> element("button[phx-click='select_contact'][phx-value-id='003abc']")
      |> render_click()

      :timer.sleep(500)

      assert has_element?(view, "#salesforce-modal-wrapper")
    end
  end

  describe "Salesforce API behavior delegation" do
    setup do
      user = user_fixture()
      credential = salesforce_credential_fixture(%{user_id: user.id})
      %{credential: credential}
    end

    test "search_contacts delegates to implementation", %{credential: credential} do
      expected = [%{id: "003abc", firstname: "Test", lastname: "User"}]

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _cred, query ->
        assert query == "test query"
        {:ok, expected}
      end)

      assert {:ok, ^expected} =
               SocialScribe.SalesforceApiBehaviour.search_contacts(credential, "test query")
    end

    test "get_contact delegates to implementation", %{credential: credential} do
      expected = %{id: "003abc", firstname: "Jane", lastname: "Smith"}

      SocialScribe.SalesforceApiMock
      |> expect(:get_contact, fn _cred, contact_id ->
        assert contact_id == "003abc"
        {:ok, expected}
      end)

      assert {:ok, ^expected} =
               SocialScribe.SalesforceApiBehaviour.get_contact(credential, "003abc")
    end

    test "update_contact delegates to implementation", %{credential: credential} do
      updates = %{"phone" => "555-1234", "jobtitle" => "CTO"}
      expected = %{id: "003abc", phone: "555-1234", jobtitle: "CTO"}

      SocialScribe.SalesforceApiMock
      |> expect(:update_contact, fn _cred, contact_id, upd ->
        assert contact_id == "003abc"
        assert upd == updates
        {:ok, expected}
      end)

      assert {:ok, ^expected} =
               SocialScribe.SalesforceApiBehaviour.update_contact(credential, "003abc", updates)
    end

    test "apply_updates delegates to implementation", %{credential: credential} do
      updates_list = [
        %{field: "phone", new_value: "555-1234", apply: true},
        %{field: "email", new_value: "test@example.com", apply: false}
      ]

      SocialScribe.SalesforceApiMock
      |> expect(:apply_updates, fn _cred, contact_id, list ->
        assert contact_id == "003abc"
        assert list == updates_list
        {:ok, %{id: "003abc"}}
      end)

      assert {:ok, _} =
               SocialScribe.SalesforceApiBehaviour.apply_updates(
                 credential,
                 "003abc",
                 updates_list
               )
    end
  end

  defp meeting_fixture_with_transcript(user) do
    meeting = meeting_fixture(%{})

    calendar_event = SocialScribe.Calendar.get_calendar_event!(meeting.calendar_event_id)

    {:ok, _updated_event} =
      SocialScribe.Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{
        "data" => [
          %{
            "speaker" => "Jane Smith",
            "words" => [
              %{"text" => "Hi,"},
              %{"text" => "my"},
              %{"text" => "new"},
              %{"text" => "phone"},
              %{"text" => "is"},
              %{"text" => "555-9999"}
            ]
          }
        ]
      }
    })

    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end
end
