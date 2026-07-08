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

  describe "GET /api/games/:platform/:external_id/achievements" do
    setup %{user: user, authed: authed} do
      {:ok, game} = Catalog.upsert_game(%{
        platform: "retroachievements",
        external_id: "celeste-ra",
        title: "Celeste",
        image_url: nil,
        total_achievements: 2
      })
      {:ok, ach1} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "C1", title: "Summit", description: nil, points: 50, image_url: nil})
      {:ok, ach2} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "C2", title: "Locked", description: nil, points: 10, image_url: nil})
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Catalog.upsert_user_game(%{user_id: user.id, game_id: game.id, unlocked_count: 1,
        is_beaten: false, is_mastered: false, last_synced_at: now})
      Catalog.insert_user_achievements([%{user_id: user.id, achievement_id: ach1.id, unlocked_at: now}])
      %{game: game, ach1: ach1, ach2: ach2}
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/games/retroachievements/celeste-ra/achievements")
      assert json_response(conn, 401)
    end

    test "returns 404 when game does not exist", %{authed: conn} do
      conn = get(conn, "/api/games/retroachievements/nonexistent/achievements")
      assert json_response(conn, 404)
    end

    test "returns 404 when game exists but user has no UserGame", %{user: _user, authed: _authed} do
      {:ok, other} = Accounts.register_user(%{username: "other_gc", email: "other_gc@example.com", password: "secret123"})
      {:ok, other_token, _} = Guardian.encode_and_sign(other)
      other_conn = build_conn() |> put_req_header("authorization", "Bearer #{other_token}")
      conn = get(other_conn, "/api/games/retroachievements/celeste-ra/achievements")
      assert json_response(conn, 404)
    end

    test "returns game info and all achievements", %{authed: conn} do
      conn = get(conn, "/api/games/retroachievements/celeste-ra/achievements")
      body = json_response(conn, 200)

      assert body["game"]["title"] == "Celeste"
      assert body["game"]["platform"] == "retroachievements"
      assert body["game"]["total_achievements"] == 2
      assert length(body["items"]) == 2
    end

    test "marks unlocked and locked achievements correctly", %{authed: conn} do
      conn = get(conn, "/api/games/retroachievements/celeste-ra/achievements")
      items = json_response(conn, 200)["items"]

      unlocked = Enum.find(items, &(&1["title"] == "Summit"))
      locked = Enum.find(items, &(&1["title"] == "Locked"))

      assert unlocked["unlocked"] == true
      assert unlocked["unlocked_at"] != nil
      assert locked["unlocked"] == false
      assert locked["unlocked_at"] == nil
    end

    test "returns unlocked achievements before locked", %{authed: conn} do
      conn = get(conn, "/api/games/retroachievements/celeste-ra/achievements")
      items = json_response(conn, 200)["items"]
      [first | _] = items
      assert first["unlocked"] == true
    end
  end

  describe "GET /api/games with platform filter" do
    setup %{user: user} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, gba_game} = Catalog.upsert_game(%{platform: "gba", external_id: "gba1", title: "GBA Game", total_achievements: 3})
      {:ok, psx_game} = Catalog.upsert_game(%{platform: "psx", external_id: "psx1", title: "PSX Game", total_achievements: 5})
      Catalog.upsert_user_game(%{user_id: user.id, game_id: gba_game.id, unlocked_count: 1,
        is_beaten: false, is_mastered: false, last_synced_at: now})
      Catalog.upsert_user_game(%{user_id: user.id, game_id: psx_game.id, unlocked_count: 2,
        is_beaten: false, is_mastered: false, last_synced_at: now})
      %{gba_game: gba_game, psx_game: psx_game}
    end

    test "filters by platform", %{authed: conn} do
      conn = get(conn, "/api/games?platform=gba")
      games = json_response(conn, 200)
      assert length(games) == 1
      assert hd(games)["platform"] == "gba"
    end

    test "returns all games when no platform filter", %{authed: conn} do
      conn = get(conn, "/api/games")
      # includes the 2 from main setup + 2 from this setup = 4
      assert length(json_response(conn, 200)) == 4
    end
  end

  describe "GET /api/games/platforms" do
    setup %{user: user} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, g1} = Catalog.upsert_game(%{platform: "gba", external_id: "p1", title: "GBA G", total_achievements: 1})
      {:ok, g2} = Catalog.upsert_game(%{platform: "steam", external_id: "p2", title: "Steam G", total_achievements: 1})
      Catalog.upsert_user_game(%{user_id: user.id, game_id: g1.id, unlocked_count: 0,
        is_beaten: false, is_mastered: false, last_synced_at: now})
      Catalog.upsert_user_game(%{user_id: user.id, game_id: g2.id, unlocked_count: 0,
        is_beaten: false, is_mastered: false, last_synced_at: now})
      :ok
    end

    test "returns unique platforms the user has games for", %{authed: conn} do
      conn = get(conn, "/api/games/platforms")
      platforms = json_response(conn, 200)["platforms"]
      assert "gba" in platforms
      assert "steam" in platforms
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/games/platforms")
      assert json_response(conn, 401)
    end
  end
end
