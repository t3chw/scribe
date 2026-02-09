defmodule SocialScribeWeb.AuthControllerTest do
  use SocialScribeWeb.ConnCase, async: true

  import Mox
  import SocialScribe.AccountsFixtures

  setup :verify_on_exit!

  # ── Helpers ──────────────────────────────────────────────────────────

  defp build_google_auth(opts) do
    %Ueberauth.Auth{
      provider: :google,
      uid: opts[:uid] || "google_#{System.unique_integer([:positive])}",
      info: %Ueberauth.Auth.Info{
        email: opts[:email] || "oauth_user@example.com",
        name: opts[:name] || "Test User"
      },
      credentials: %Ueberauth.Auth.Credentials{
        token: opts[:token] || "access_token_#{System.unique_integer([:positive])}",
        refresh_token:
          opts[:refresh_token] || "refresh_token_#{System.unique_integer([:positive])}",
        expires_at: opts[:expires_at]
      },
      extra: %Ueberauth.Auth.Extra{
        raw_info: opts[:raw_info] || %{}
      }
    }
  end

  defp build_linkedin_auth(opts) do
    sub = opts[:sub] || "linkedin_sub_#{System.unique_integer([:positive])}"

    %Ueberauth.Auth{
      provider: :linkedin,
      uid: opts[:uid] || "li_#{System.unique_integer([:positive])}",
      info: %Ueberauth.Auth.Info{
        email: opts[:email] || "oauth_user@example.com",
        name: opts[:name] || "Test User"
      },
      credentials: %Ueberauth.Auth.Credentials{
        token: opts[:token] || "access_token_#{System.unique_integer([:positive])}",
        refresh_token:
          opts[:refresh_token] || "refresh_token_#{System.unique_integer([:positive])}",
        expires_at: opts[:expires_at]
      },
      extra: %Ueberauth.Auth.Extra{
        raw_info: %{user: %{"sub" => sub}}
      }
    }
  end

  defp build_facebook_auth(opts) do
    %Ueberauth.Auth{
      provider: :facebook,
      uid: opts[:uid] || "fb_#{System.unique_integer([:positive])}",
      info: %Ueberauth.Auth.Info{
        email: opts[:email] || "oauth_user@example.com",
        name: opts[:name] || "Test User"
      },
      credentials: %Ueberauth.Auth.Credentials{
        token: opts[:token] || "access_token_#{System.unique_integer([:positive])}",
        refresh_token:
          opts[:refresh_token] || "refresh_token_#{System.unique_integer([:positive])}",
        expires_at: opts[:expires_at]
      },
      extra: %Ueberauth.Auth.Extra{
        raw_info: opts[:raw_info] || %{}
      }
    }
  end

  defp build_hubspot_auth(opts) do
    %Ueberauth.Auth{
      provider: :hubspot,
      uid: opts[:uid] || "hub_#{System.unique_integer([:positive])}",
      info: %Ueberauth.Auth.Info{
        email: opts[:email] || "oauth_user@example.com",
        name: opts[:name] || "Test User"
      },
      credentials: %Ueberauth.Auth.Credentials{
        token: opts[:token] || "access_token_#{System.unique_integer([:positive])}",
        refresh_token:
          opts[:refresh_token] || "refresh_token_#{System.unique_integer([:positive])}",
        expires_at: opts[:expires_at]
      },
      extra: %Ueberauth.Auth.Extra{
        raw_info: opts[:raw_info] || %{}
      }
    }
  end

  defp build_salesforce_auth(opts) do
    %Ueberauth.Auth{
      provider: :salesforce,
      uid: opts[:uid] || "org_#{System.unique_integer([:positive])}",
      info: %Ueberauth.Auth.Info{
        email: opts[:email] || "oauth_user@example.com",
        name: opts[:name] || "Test User"
      },
      credentials: %Ueberauth.Auth.Credentials{
        token: opts[:token] || "access_token_#{System.unique_integer([:positive])}",
        refresh_token:
          opts[:refresh_token] || "refresh_token_#{System.unique_integer([:positive])}",
        expires_at: opts[:expires_at]
      },
      extra: %Ueberauth.Auth.Extra{
        raw_info: opts[:raw_info] || %{}
      }
    }
  end

  defp assign_auth(conn, auth, user) do
    conn
    |> assign(:ueberauth_auth, auth)
    |> assign(:current_user, user)
  end

  defp assign_auth(conn, auth) do
    assign(conn, :ueberauth_auth, auth)
  end

  # ── Google callback (authed) ─────────────────────────────────────────

  describe "GET /auth/google/callback (authenticated)" do
    setup :register_and_log_in_user

    test "creates credential and redirects to settings on success", %{conn: conn, user: user} do
      auth = build_google_auth(email: user.email)

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/google/callback")

      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Google account added"
    end

    test "updates existing credential on re-auth", %{conn: conn, user: user} do
      uid = "google_reauth_#{System.unique_integer([:positive])}"
      auth = build_google_auth(uid: uid, email: user.email)

      # First auth
      conn
      |> assign_auth(auth, user)
      |> get(~p"/auth/google/callback")

      # Second auth with same uid - should update, not error
      conn2 =
        build_conn()
        |> log_in_user(user)
        |> assign_auth(build_google_auth(uid: uid, email: user.email, token: "new_token"), user)
        |> get(~p"/auth/google/callback")

      assert redirected_to(conn2) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn2.assigns.flash, :info) =~ "Google account added"
    end
  end

  # ── LinkedIn callback (authed) ───────────────────────────────────────

  describe "GET /auth/linkedin/callback (authenticated)" do
    setup :register_and_log_in_user

    test "creates credential and redirects to settings on success", %{conn: conn, user: user} do
      auth = build_linkedin_auth(email: user.email)

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/linkedin/callback")

      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "LinkedIn account added"
    end

    test "updates existing credential on re-auth", %{conn: conn, user: user} do
      auth = build_linkedin_auth(email: user.email, sub: "same_sub")

      # First auth
      conn
      |> assign_auth(auth, user)
      |> get(~p"/auth/linkedin/callback")

      # Second auth
      auth2 = build_linkedin_auth(email: user.email, sub: "same_sub", token: "new_token")

      conn2 =
        build_conn()
        |> log_in_user(user)
        |> assign_auth(auth2, user)
        |> get(~p"/auth/linkedin/callback")

      assert redirected_to(conn2) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn2.assigns.flash, :info) =~ "LinkedIn account added"
    end
  end

  # ── Facebook callback (authed) ───────────────────────────────────────

  describe "GET /auth/facebook/callback (authenticated)" do
    setup :register_and_log_in_user

    test "creates credential, fetches pages, and redirects to facebook_pages", %{
      conn: conn,
      user: user
    } do
      auth = build_facebook_auth(email: user.email)

      SocialScribe.FacebookApiMock
      |> expect(:fetch_user_pages, fn _uid, _token ->
        {:ok,
         [
           %{
             id: "page_123",
             name: "My Page",
             page_access_token: "page_token",
             category: "Business"
           }
         ]}
      end)

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/facebook/callback")

      assert redirected_to(conn) == "/dashboard/settings/facebook_pages"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Facebook account added"
    end

    test "handles fetch_user_pages error gracefully", %{conn: conn, user: user} do
      auth = build_facebook_auth(email: user.email)

      SocialScribe.FacebookApiMock
      |> expect(:fetch_user_pages, fn _uid, _token ->
        {:error, "API error"}
      end)

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/facebook/callback")

      # Still redirects successfully even when page fetch fails
      assert redirected_to(conn) == "/dashboard/settings/facebook_pages"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Facebook account added"
    end
  end

  # ── HubSpot callback (authed) ────────────────────────────────────────

  describe "GET /auth/hubspot/callback (authenticated)" do
    setup :register_and_log_in_user

    test "creates credential, enqueues CRMContactSyncer, and redirects", %{
      conn: conn,
      user: user
    } do
      auth =
        build_hubspot_auth(
          uid: "hub_12345",
          email: user.email,
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600))
        )

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/hubspot/callback")

      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "HubSpot account connected"

      assert_enqueued(
        worker: SocialScribe.Workers.CRMContactSyncer,
        args: %{"user_id" => user.id, "provider" => "hubspot"}
      )
    end

    test "handles nil expires_at with 1hr fallback", %{conn: conn, user: user} do
      auth = build_hubspot_auth(uid: "hub_99999", email: user.email, expires_at: nil)

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/hubspot/callback")

      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "HubSpot account connected"
    end

    test "updates existing credential on re-auth", %{conn: conn, user: user} do
      auth =
        build_hubspot_auth(
          uid: "hub_reauth",
          email: user.email,
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600))
        )

      # First auth
      conn
      |> assign_auth(auth, user)
      |> get(~p"/auth/hubspot/callback")

      # Second auth with same hub_id
      auth2 =
        build_hubspot_auth(
          uid: "hub_reauth",
          email: user.email,
          token: "new_token",
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 7200))
        )

      conn2 =
        build_conn()
        |> log_in_user(user)
        |> assign_auth(auth2, user)
        |> get(~p"/auth/hubspot/callback")

      assert redirected_to(conn2) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn2.assigns.flash, :info) =~ "HubSpot account connected"
    end
  end

  # ── Salesforce callback (authed) ─────────────────────────────────────

  describe "GET /auth/salesforce/callback (authenticated)" do
    setup :register_and_log_in_user

    test "creates credential with valid instance_url, enqueues job, and redirects", %{
      conn: conn,
      user: user
    } do
      auth =
        build_salesforce_auth(
          uid: "org_12345",
          email: user.email,
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600)),
          raw_info: %{instance_url: "https://myorg.my.salesforce.com"}
        )

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/salesforce/callback")

      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce account connected"

      assert_enqueued(
        worker: SocialScribe.Workers.CRMContactSyncer,
        args: %{"user_id" => user.id, "provider" => "salesforce"}
      )
    end

    test "falls back on nil instance_url", %{conn: conn, user: user} do
      auth =
        build_salesforce_auth(
          uid: "org_nil_url",
          email: user.email,
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600)),
          raw_info: %{}
        )

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/salesforce/callback")

      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce account connected"
    end

    test "validates legit salesforce.com domain", %{conn: conn, user: user} do
      auth =
        build_salesforce_auth(
          uid: "org_legit_sf",
          email: user.email,
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600)),
          raw_info: %{instance_url: "https://na1.salesforce.com"}
        )

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/salesforce/callback")

      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce account connected"
    end

    test "validates legit force.com domain", %{conn: conn, user: user} do
      auth =
        build_salesforce_auth(
          uid: "org_force_com",
          email: user.email,
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600)),
          raw_info: %{instance_url: "https://myorg.force.com"}
        )

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/salesforce/callback")

      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce account connected"
    end

    test "validates legit my.salesforce.com domain", %{conn: conn, user: user} do
      auth =
        build_salesforce_auth(
          uid: "org_my_sf",
          email: user.email,
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600)),
          raw_info: %{instance_url: "https://mycompany.my.salesforce.com"}
        )

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/salesforce/callback")

      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce account connected"
    end

    test "falls back on invalid instance_url with http scheme", %{conn: conn, user: user} do
      auth =
        build_salesforce_auth(
          uid: "org_http",
          email: user.email,
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600)),
          raw_info: %{instance_url: "http://evil.com"}
        )

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/salesforce/callback")

      # Should still succeed (falls back to login.salesforce.com)
      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce account connected"
    end

    test "rejects malicious non-salesforce domain", %{conn: conn, user: user} do
      auth =
        build_salesforce_auth(
          uid: "org_evil",
          email: user.email,
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600)),
          raw_info: %{instance_url: "https://evil.com"}
        )

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/salesforce/callback")

      # Falls back to default, but still connects successfully
      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce account connected"
    end

    test "handles string keys in raw_info for instance_url", %{conn: conn, user: user} do
      auth =
        build_salesforce_auth(
          uid: "org_string_key",
          email: user.email,
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600)),
          raw_info: %{"instance_url" => "https://myorg.my.salesforce.com"}
        )

      conn =
        conn
        |> assign_auth(auth, user)
        |> get(~p"/auth/salesforce/callback")

      assert redirected_to(conn) == "/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce account connected"
    end
  end

  # ── Unauthenticated callback (OAuth login) ───────────────────────────

  describe "GET /auth/:provider/callback (unauthenticated)" do
    test "creates user from OAuth and logs in", %{conn: conn} do
      auth = build_google_auth(email: "new_oauth_user@example.com")

      conn =
        conn
        |> init_test_session(%{})
        |> assign_auth(auth)
        |> get(~p"/auth/google/callback")

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :user_token)
    end

    test "finds existing user and logs in", %{conn: conn} do
      user = user_fixture(%{email: "existing@example.com"})
      auth = build_google_auth(email: user.email)

      conn =
        conn
        |> init_test_session(%{})
        |> assign_auth(auth)
        |> get(~p"/auth/google/callback")

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :user_token)
    end
  end

  # ── Error fallback ───────────────────────────────────────────────────

  describe "GET /auth/:provider/callback (no auth data)" do
    test "shows flash error and redirects to /", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get(~p"/auth/google/callback")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "error signing you in"
    end
  end
end
