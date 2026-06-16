defmodule AchievTrackWeb.HomeControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.{Accounts, Auth.Guardian, Catalog}

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "home_ctrl", email: "homectrl@example.com", password: "secret123"
    })
    {:ok, token, _} = Guardian.encode_and_sign(user)
    authed = build_conn() |> put_req_header("authorization", "Bearer #{token}")

    {:ok, game} = Catalog.upsert_game(%{
      platform: "steam", external_id: "home1", title: "HomeGame", total_achievements: 3
    })
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Catalog.upsert_user_game(%{
      user_id: user.id, game_id: game.id, playtime_forever: 0, unlocked_count: 1,
      is_beaten: false, is_mastered: false, last_synced_at: now
    })
    {:ok, ach} = Catalog.upsert_achievement(%{
      game_id: game.id, external_id: "H1", title: "HAch", description: nil, points: 10
    })
    Catalog.insert_user_achievements([%{user_id: user.id, achievement_id: ach.id, unlocked_at: now}])

    %{user: user, authed: authed}
  end

  test "returns 401 without token", %{conn: conn} do
    conn = get(conn, "/api/home")
    assert json_response(conn, 401)
  end

  test "returns stats, recent_achievements, active_games, popular_games", %{authed: conn} do
    conn = get(conn, "/api/home")
    body = json_response(conn, 200)
    assert %{"stats" => stats, "recent_achievements" => ra, "active_games" => ag, "popular_games" => pg} = body
    assert stats["total_achievements"] == 1
    assert stats["total_points"] == 10
    assert length(ra) == 1
    assert hd(ra)["title"] == "HAch"
    assert length(ag) == 1
    assert is_list(pg)
  end
end
