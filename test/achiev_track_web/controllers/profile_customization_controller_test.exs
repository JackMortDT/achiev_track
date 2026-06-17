defmodule AchievTrackWeb.ProfileCustomizationControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.{Accounts, Catalog, Repo}
  alias AchievTrack.Catalog.{Achievement, UserAchievement}

  setup %{conn: conn} do
    {:ok, user} = Accounts.register_user(%{
      username: "custom_user",
      email: "custom@example.com",
      password: "secret123"
    })
    {:ok, token, _} = AchievTrack.Auth.Guardian.encode_and_sign(user)
    authed = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, game} = Catalog.upsert_game(%{
      platform: "steam", external_id: "440", title: "TF2", total_achievements: 5
    })
    Catalog.upsert_user_game(%{
      user_id: user.id, game_id: game.id,
      unlocked_count: 3, is_beaten: false, is_mastered: false,
      playtime_forever: 100,
      last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    {:ok, achievement} = Repo.insert(Achievement.changeset(%Achievement{}, %{
      game_id: game.id, external_id: "ACH_1", title: "First Blood",
      description: "Kill", points: 50
    }))
    {:ok, ua} = Repo.insert(UserAchievement.changeset(%UserAchievement{}, %{
      user_id: user.id, achievement_id: achievement.id,
      unlocked_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }))
    %{authed: authed, game: game, ua: ua}
  end

  describe "PATCH /api/me/favorite-game" do
    test "sets favorite game", %{authed: conn, game: game} do
      resp = patch(conn, "/api/me/favorite-game", %{game_id: game.id})
      assert resp.status == 200
      assert Jason.decode!(resp.resp_body)["ok"] == true
    end

    test "clears favorite game when game_id is nil", %{authed: conn, game: game} do
      patch(conn, "/api/me/favorite-game", %{game_id: game.id})
      resp = patch(conn, "/api/me/favorite-game", %{game_id: nil})
      assert resp.status == 200
    end

    test "returns 422 for game not in user library", %{authed: conn} do
      {:ok, other} = Catalog.upsert_game(%{
        platform: "steam", external_id: "999", title: "Other", total_achievements: 0
      })
      resp = patch(conn, "/api/me/favorite-game", %{game_id: other.id})
      assert resp.status == 422
    end
  end

  describe "PUT /api/me/showcase/games" do
    test "sets game showcase", %{authed: conn, game: game} do
      resp = put(conn, "/api/me/showcase/games", %{game_ids: [game.id]})
      assert resp.status == 200
      assert Jason.decode!(resp.resp_body)["ok"] == true
    end

    test "clears showcase with empty list", %{authed: conn} do
      resp = put(conn, "/api/me/showcase/games", %{game_ids: []})
      assert resp.status == 200
    end

    test "returns 422 for more than 6 games", %{authed: conn, game: game} do
      resp = put(conn, "/api/me/showcase/games", %{game_ids: List.duplicate(game.id, 7)})
      assert resp.status == 422
    end
  end

  describe "PUT /api/me/showcase/achievements" do
    test "sets achievement showcase", %{authed: conn, ua: ua} do
      resp = put(conn, "/api/me/showcase/achievements", %{user_achievement_ids: [ua.id]})
      assert resp.status == 200
      assert Jason.decode!(resp.resp_body)["ok"] == true
    end

    test "returns 422 for more than 5 achievements", %{authed: conn, ua: ua} do
      resp = put(conn, "/api/me/showcase/achievements",
        %{user_achievement_ids: List.duplicate(ua.id, 6)})
      assert resp.status == 422
    end
  end
end
