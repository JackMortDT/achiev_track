defmodule AchievTrack.FeedTest do
  use AchievTrack.DataCase

  alias AchievTrack.{Accounts, Catalog, Feed}

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "feed_user",
      email: "feed@example.com",
      password: "secret123"
    })
    %{user: user}
  end

  describe "Feed.get_user_stats/1" do
    test "returns zeros for a new user", %{user: user} do
      stats = Feed.get_user_stats(user.id)
      assert stats.total_achievements == 0
      assert stats.total_games == 0
      assert stats.total_points == 0
    end

    test "returns correct aggregates after inserting catalog data", %{user: user} do
      {:ok, game} = Catalog.upsert_game(%{platform: "steam", external_id: "440", title: "TF2", total_achievements: 2})
      {:ok, ach1} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "A1", title: "Ach1", points: 10})
      {:ok, ach2} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "A2", title: "Ach2", points: 25})
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Catalog.insert_user_achievements([
        %{user_id: user.id, achievement_id: ach1.id, unlocked_at: now},
        %{user_id: user.id, achievement_id: ach2.id, unlocked_at: now}
      ])
      Catalog.upsert_user_game(%{user_id: user.id, game_id: game.id, unlocked_count: 2,
        is_beaten: false, is_mastered: true, last_synced_at: now})

      stats = Feed.get_user_stats(user.id)
      assert stats.total_achievements == 2
      assert stats.total_games == 1
      assert stats.total_points == 35
    end
  end

  describe "Feed.list_user_achievements/2" do
    setup %{user: user} do
      {:ok, game} = Catalog.upsert_game(%{platform: "steam", external_id: "440", title: "TF2", total_achievements: 2})
      {:ok, ach1} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "A1", title: "First", points: 10})
      {:ok, ach2} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "A2", title: "Second", points: 50})
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      earlier = DateTime.add(now, -3600, :second)
      Catalog.insert_user_achievements([
        %{user_id: user.id, achievement_id: ach1.id, unlocked_at: earlier},
        %{user_id: user.id, achievement_id: ach2.id, unlocked_at: now}
      ])
      %{game: game}
    end

    test "returns empty list for new user" do
      {:ok, other} = Accounts.register_user(%{username: "empty_user", email: "empty@example.com", password: "secret123"})
      assert [] = Feed.list_user_achievements(other.id)
    end

    test "returns achievements sorted by date desc (default)", %{user: user} do
      results = Feed.list_user_achievements(user.id)
      assert length(results) == 2
      [first, second] = results
      assert first.title == "Second"
      assert second.title == "First"
    end

    test "filters by platform", %{user: user} do
      {:ok, ra_game} = Catalog.upsert_game(%{platform: "retroachievements", external_id: "99", title: "RA Game", total_achievements: 1})
      {:ok, ra_ach} = Catalog.upsert_achievement(%{game_id: ra_game.id, external_id: "RA1", title: "RA Ach", points: 5})
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Catalog.insert_user_achievements([%{user_id: user.id, achievement_id: ra_ach.id, unlocked_at: now}])

      steam_results = Feed.list_user_achievements(user.id, platform: "steam")
      assert Enum.all?(steam_results, &(&1.platform == "steam"))
      assert length(steam_results) == 2

      ra_results = Feed.list_user_achievements(user.id, platform: "retroachievements")
      assert length(ra_results) == 1
    end

    test "sorts by points when sort: points given", %{user: user} do
      results = Feed.list_user_achievements(user.id, sort: "points")
      assert hd(results).points == 50
    end

    test "sorts by game name ascending when sort: game given", %{user: user} do
      # The existing setup has achievements for "TF2". Add another game that sorts before it.
      {:ok, aaa_game} = Catalog.upsert_game(%{platform: "steam", external_id: "1", title: "AAA Game", total_achievements: 1})
      {:ok, aaa_ach} = Catalog.upsert_achievement(%{game_id: aaa_game.id, external_id: "AAA1", title: "AAA Ach", points: 1})
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Catalog.insert_user_achievements([%{user_id: user.id, achievement_id: aaa_ach.id, unlocked_at: now}])

      results = Feed.list_user_achievements(user.id, sort: "game")
      # "AAA Game" sorts before "TF2" alphabetically
      assert hd(results).game_title == "AAA Game"
    end
  end

  describe "Feed.list_user_games/2" do
    setup %{user: user} do
      {:ok, g1} = Catalog.upsert_game(%{platform: "steam", external_id: "1", title: "Game1", total_achievements: 10})
      {:ok, g2} = Catalog.upsert_game(%{platform: "steam", external_id: "2", title: "Game2", total_achievements: 5})
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Catalog.upsert_user_game(%{user_id: user.id, game_id: g1.id, unlocked_count: 10,
        is_beaten: true, is_mastered: true, last_synced_at: now})
      Catalog.upsert_user_game(%{user_id: user.id, game_id: g2.id, unlocked_count: 2,
        is_beaten: false, is_mastered: false, last_synced_at: now})
      %{g1: g1, g2: g2}
    end

    test "returns all games with no filter", %{user: user} do
      assert length(Feed.list_user_games(user.id)) == 2
    end

    test "filters mastered games", %{user: user} do
      games = Feed.list_user_games(user.id, "mastered")
      assert length(games) == 1
      assert hd(games).is_mastered == true
    end

    test "filters beaten (not mastered) games", %{user: user} do
      {:ok, g3} = Catalog.upsert_game(%{platform: "steam", external_id: "3", title: "Game3", total_achievements: 5})
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Catalog.upsert_user_game(%{user_id: user.id, game_id: g3.id, unlocked_count: 3,
        is_beaten: true, is_mastered: false, last_synced_at: now})

      games = Feed.list_user_games(user.id, "beaten")
      assert length(games) == 1
      assert hd(games).title == "Game3"
      assert hd(games).is_beaten == true
      assert hd(games).is_mastered == false
    end

    test "filters in_progress games (not beaten)", %{user: user} do
      games = Feed.list_user_games(user.id, "in_progress")
      assert length(games) == 1
      assert hd(games).is_beaten == false
    end
  end
end
