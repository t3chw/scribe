defmodule SocialScribeWeb.ChatPanelTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures

  describe "Chat Panel" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "Ask Anything button is visible on dashboard", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Ask Anything"
    end

    test "chat panel starts closed", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "translate-x-full"
    end

    test "clicking Ask Anything toggles chat open", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      html = render_click(view, "toggle_chat")

      assert html =~ "translate-x-0"
    end

    test "chat panel has Chat and History tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      render_click(view, "toggle_chat")
      html = render(view)

      assert html =~ "Chat"
      assert html =~ "History"
    end

    test "empty state shows welcome message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      render_click(view, "toggle_chat")
      html = render(view)

      assert html =~ "I can answer questions about Jump meetings and data"
    end

    test "chat panel renders on meetings page too", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      assert html =~ "Ask Anything"
    end

    test "chat panel shows Sources label in input area", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      render_click(view, "toggle_chat")
      html = render(view)

      assert html =~ "Sources"
    end

    test "chat panel shows meetings source icon by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      render_click(view, "toggle_chat")
      html = render(view)

      assert html =~ "text-slate-800"
    end

    test "chat panel shows @ Add context label", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      render_click(view, "toggle_chat")
      html = render(view)

      assert html =~ "@ Add context"
    end
  end
end
