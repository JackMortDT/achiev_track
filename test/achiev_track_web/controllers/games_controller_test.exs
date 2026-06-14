defmodule AchievTrackWeb.GamesControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.{Accounts, Catalog}
  alias AchievTrack.Auth.Guardian

  setup do
    {:ok, user} = Accounts.register_user(%{username: "games_user", email: "games@example.com", password: "secret123"})
    {:ok, token, _} = Guardian.encode_and_sign(user)
    authed = build_conn() |> put_req_header("authorization", "Bearer #{token}")

    {:ok, g1} = Catalog.upsert_game(%{platform: "steam", external_id: "1", title: "Mastered", total_achievements: 5})
    {:ok, g2} = Catalog.upsert_game(%{platform: "steam", external_id: "2", title: "InProgress", total_achievements: 10})
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Catalog.upsert_user_game(%{user_id: user.id, game_id: g1.id, unlocked_count: 5,
      is_beaten: true, is_mastered: true, last_synced_at: now})
    Catalog.upsert_user_game(%{user_id: user.id, game_id: g2.id, unlocked_count: 2,
      is_beaten: false, is_mastered: false, last_synced_at: now})

    %{user: user, authed: authed}
  end

  test "GET /api/games returns 401 without token", %{conn: conn} do
    conn = get(conn, "/api/games")
    assert json_response(conn, 401)
  end

  test "GET /api/games returns all games by default", %{authed: conn} do
    conn = get(conn, "/api/games")
    assert length(json_response(conn, 200)) == 2
  end

  test "GET /api/games?status=mastered returns only mastered games", %{authed: conn} do
    conn = get(conn, "/api/games?status=mastered")
    games = json_response(conn, 200)
    assert length(games) == 1
    assert hd(games)["title"] == "Mastered"
  end

  test "GET /api/games?status=in_progress returns unbeaten games", %{authed: conn} do
    conn = get(conn, "/api/games?status=in_progress")
    games = json_response(conn, 200)
    assert length(games) == 1
    assert hd(games)["title"] == "InProgress"
  end

  test "GET /api/games?status=beaten returns beaten (not mastered) games", %{user: user, authed: conn} do
    {:ok, g3} = Catalog.upsert_game(%{platform: "steam", external_id: "3", title: "BeatGame", total_achievements: 5})
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Catalog.upsert_user_game(%{user_id: user.id, game_id: g3.id, unlocked_count: 3,
      is_beaten: true, is_mastered: false, last_synced_at: now})

    conn = get(conn, "/api/games?status=beaten")
    games = json_response(conn, 200)
    assert length(games) == 1
    assert hd(games)["title"] == "BeatGame"
  end
end
