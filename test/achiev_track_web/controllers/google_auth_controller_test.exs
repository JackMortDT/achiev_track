defmodule AchievTrackWeb.GoogleAuthControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.Auth.GoogleAuthState

  describe "GET /api/auth/google/login" do
    test "returns google_url without requiring auth", %{conn: conn} do
      conn = get(conn, "/api/auth/google/login")
      body = json_response(conn, 200)
      assert %{"google_url" => url} = body
      assert String.contains?(url, "accounts.google.com")
      assert String.contains?(url, "state")
    end
  end

  describe "GET /auth/google/callback" do
    test "redirects to login with error when state is invalid", %{conn: conn} do
      conn = get(conn, "/auth/google/callback", %{"state" => "bad", "code" => "code"})
      assert redirected_to(conn) =~ "/login?google=error"
    end

    test "redirects to login with error when no code param", %{conn: conn} do
      state = "test-state-#{System.unique_integer()}"
      GoogleAuthState.put(state)
      conn = get(conn, "/auth/google/callback", %{"state" => state})
      assert redirected_to(conn) =~ "/login?google=error"
    end
  end
end
