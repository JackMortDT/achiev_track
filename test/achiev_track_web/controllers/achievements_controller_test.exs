defmodule AchievTrackWeb.AchievementsControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.{Accounts, Catalog}
  alias AchievTrack.Auth.Guardian

  setup do
    {:ok, user} = Accounts.register_user(%{username: "ach_user", email: "ach@example.com", password: "secret123"})
    {:ok, token, _} = Guardian.encode_and_sign(user)
    authed = build_conn() |> put_req_header("authorization", "Bearer #{token}")
    %{user: user, authed: authed}
  end

  test "GET /api/achievements returns 401 without token", %{conn: conn} do
    conn = get(conn, "/api/achievements")
    assert json_response(conn, 401)
  end

  test "GET /api/achievements returns empty list for new user", %{authed: conn} do
    conn = get(conn, "/api/achievements")
    assert %{"items" => []} = json_response(conn, 200)
  end

  test "GET /api/achievements returns achievements for user", %{user: user, authed: conn} do
    {:ok, game} = Catalog.upsert_game(%{platform: "steam", external_id: "440", title: "TF2", total_achievements: 1})
    {:ok, ach} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "A1", title: "First", points: 10})
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Catalog.insert_user_achievements([%{user_id: user.id, achievement_id: ach.id, unlocked_at: now}])

    conn = get(conn, "/api/achievements")
    %{"items" => [result]} = json_response(conn, 200)
    assert result["title"] == "First"
    assert result["game_title"] == "TF2"
    assert result["platform"] == "steam"
    assert result["points"] == 10
  end

  test "GET /api/achievements filters by platform", %{user: user, authed: conn} do
    {:ok, sg} = Catalog.upsert_game(%{platform: "steam", external_id: "1", title: "Steam Game", total_achievements: 1})
    {:ok, rg} = Catalog.upsert_game(%{platform: "retroachievements", external_id: "2", title: "RA Game", total_achievements: 1})
    {:ok, sa} = Catalog.upsert_achievement(%{game_id: sg.id, external_id: "S1", title: "Steam Ach", points: 5})
    {:ok, ra} = Catalog.upsert_achievement(%{game_id: rg.id, external_id: "R1", title: "RA Ach", points: 5})
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Catalog.insert_user_achievements([
      %{user_id: user.id, achievement_id: sa.id, unlocked_at: now},
      %{user_id: user.id, achievement_id: ra.id, unlocked_at: now}
    ])

    conn = get(conn, "/api/achievements?platform=steam")
    %{"items" => results} = json_response(conn, 200)
    assert length(results) == 1
    assert hd(results)["platform"] == "steam"
  end

  test "GET /api/achievements?sort=points returns achievements sorted by points desc", %{user: user, authed: conn} do
    {:ok, game} = Catalog.upsert_game(%{platform: "steam", external_id: "500", title: "Sort Game", total_achievements: 2})
    {:ok, low} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "LOW", title: "Low Points", points: 5})
    {:ok, high} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "HIGH", title: "High Points", points: 100})
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Catalog.insert_user_achievements([
      %{user_id: user.id, achievement_id: low.id, unlocked_at: now},
      %{user_id: user.id, achievement_id: high.id, unlocked_at: now}
    ])

    conn = get(conn, "/api/achievements?sort=points")
    %{"items" => [first | _]} = json_response(conn, 200)
    assert first["title"] == "High Points"
    assert first["points"] == 100
  end
end
