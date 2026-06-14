defmodule AchievTrackWeb.ProfileControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.Accounts
  alias AchievTrack.Auth.Guardian

  setup do
    {:ok, user} = Accounts.register_user(%{username: "prof_user", email: "prof@example.com", password: "secret123"})
    {:ok, token, _} = Guardian.encode_and_sign(user)
    authed = build_conn() |> put_req_header("authorization", "Bearer #{token}")
    %{user: user, authed: authed}
  end

  test "GET /api/profile requires auth", %{conn: conn} do
    conn = get(conn, "/api/profile")
    assert %{"error" => "Unauthorized"} = json_response(conn, 401)
  end

  test "GET /api/profile returns user stats and platforms", %{user: user, authed: conn} do
    Accounts.connect_platform(user, "steam", %{"external_id" => "76561198000000000"})
    conn = get(conn, "/api/profile")
    body = json_response(conn, 200)
    assert body["user"]["username"] == "prof_user"
    assert body["stats"]["total_achievements"] == 0
    assert body["stats"]["total_games"] == 0
    assert body["stats"]["total_points"] == 0
    assert length(body["platforms"]) == 1
    assert body["sync_status"]["syncs_remaining"] == 3
  end
end
