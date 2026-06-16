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

    test "orders games with most recent achievement first", %{user: user} do
      # Create a third game with a recent achievement
      {:ok, g3} = Catalog.upsert_game(%{platform: "retroachievements", external_id: "ra1", title: "RecentGame", total_achievements: 2})
      {:ok, ach} = Catalog.upsert_achievement(%{game_id: g3.id, external_id: "R1", title: "Fast", points: 10})
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Catalog.upsert_user_game(%{user_id: user.id, game_id: g3.id, unlocked_count: 1,
        is_beaten: false, is_mastered: false, last_synced_at: now})
      Catalog.insert_user_achievements([%{user_id: user.id, achievement_id: ach.id, unlocked_at: now}])

      games = Feed.list_user_games(user.id)
      # RecentGame has a user_achievement, the other two don't → it should be first
      assert hd(games).title == "RecentGame"
    end

    test "orders games with earlier achievement after more recent one", %{user: user} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      earlier = DateTime.add(now, -7200, :second)

      {:ok, ga} = Catalog.upsert_game(%{platform: "steam", external_id: "oa1", title: "OlderActive", total_achievements: 1})
      {:ok, acha} = Catalog.upsert_achievement(%{game_id: ga.id, external_id: "OA1", title: "Old", points: 5})
      Catalog.upsert_user_game(%{user_id: user.id, game_id: ga.id, unlocked_count: 1,
        is_beaten: false, is_mastered: false, last_synced_at: now})
      Catalog.insert_user_achievements([%{user_id: user.id, achievement_id: acha.id, unlocked_at: earlier}])

      {:ok, gr} = Catalog.upsert_game(%{platform: "steam", external_id: "ra2", title: "RecentActive", total_achievements: 1})
      {:ok, achr} = Catalog.upsert_achievement(%{game_id: gr.id, external_id: "RA2", title: "Recent", points: 5})
      Catalog.upsert_user_game(%{user_id: user.id, game_id: gr.id, unlocked_count: 1,
        is_beaten: false, is_mastered: false, last_synced_at: now})
      Catalog.insert_user_achievements([%{user_id: user.id, achievement_id: achr.id, unlocked_at: now}])

      titles = Feed.list_user_games(user.id) |> Enum.map(& &1.title)
      recent_idx = Enum.find_index(titles, &(&1 == "RecentActive"))
      older_idx = Enum.find_index(titles, &(&1 == "OlderActive"))
      assert recent_idx < older_idx
    end

    test "secondary sort by unlocked_count for games with no achievement activity", %{user: user} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, g_low} = Catalog.upsert_game(%{platform: "steam", external_id: "low1", title: "LowCount", total_achievements: 10})
      {:ok, g_high} = Catalog.upsert_game(%{platform: "steam", external_id: "high1", title: "HighCount", total_achievements: 10})
      Catalog.upsert_user_game(%{user_id: user.id, game_id: g_low.id, unlocked_count: 1,
        is_beaten: false, is_mastered: false, last_synced_at: now})
      Catalog.upsert_user_game(%{user_id: user.id, game_id: g_high.id, unlocked_count: 8,
        is_beaten: false, is_mastered: false, last_synced_at: now})

      # Neither game has user_achievements, so secondary sort (unlocked_count) applies
      titles = Feed.list_user_games(user.id) |> Enum.map(& &1.title)
      high_idx = Enum.find_index(titles, &(&1 == "HighCount"))
      low_idx = Enum.find_index(titles, &(&1 == "LowCount"))
      assert high_idx < low_idx
    end
  end

  describe "recent_achievements/2" do
    setup do
      {:ok, user} = AchievTrack.Accounts.register_user(%{
        username: "home_u", email: "home@example.com", password: "secret123"
      })
      {:ok, game} = AchievTrack.Catalog.upsert_game(%{
        platform: "steam", external_id: "99", title: "Game", total_achievements: 5
      })
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Enum.each(1..4, fn i ->
        {:ok, ach} = AchievTrack.Catalog.upsert_achievement(%{
          game_id: game.id, external_id: "A#{i}", title: "Ach#{i}", description: nil, points: 10
        })
        AchievTrack.Catalog.insert_user_achievements([%{
          user_id: user.id, achievement_id: ach.id,
          unlocked_at: DateTime.add(now, -i, :second)
        }])
      end)
      %{user: user}
    end

    test "returns up to limit achievements sorted by date desc", %{user: user} do
      results = AchievTrack.Feed.recent_achievements(user.id, 3)
      assert length(results) == 3
      [first | rest] = results
      assert Enum.all?(rest, fn r -> r.unlocked_at <= first.unlocked_at end)
    end
  end

  describe "popular_games/1" do
    setup do
      {:ok, g1} = AchievTrack.Catalog.upsert_game(%{
        platform: "steam", external_id: "pop1", title: "PopGame1", total_achievements: 10
      })
      {:ok, g2} = AchievTrack.Catalog.upsert_game(%{
        platform: "steam", external_id: "pop2", title: "PopGame2", total_achievements: 5
      })
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Enum.each(1..3, fn i ->
        {:ok, u} = AchievTrack.Accounts.register_user(%{
          username: "popuser#{i}", email: "pop#{i}@example.com", password: "secret123"
        })
        AchievTrack.Catalog.upsert_user_game(%{
          user_id: u.id, game_id: g1.id, unlocked_count: 1,
          is_beaten: false, is_mastered: false, last_synced_at: now
        })
      end)
      {:ok, u4} = AchievTrack.Accounts.register_user(%{
        username: "popuser4", email: "pop4@example.com", password: "secret123"
      })
      AchievTrack.Catalog.upsert_user_game(%{
        user_id: u4.id, game_id: g2.id, unlocked_count: 1,
        is_beaten: false, is_mastered: false, last_synced_at: now
      })
      %{g1: g1, g2: g2}
    end

    test "returns games ordered by player count desc", %{g1: g1} do
      results = AchievTrack.Feed.popular_games(4)
      assert hd(results).external_id == g1.external_id
      assert hd(results).player_count == 3
    end

    test "respects the limit" do
      results = AchievTrack.Feed.popular_games(1)
      assert length(results) == 1
    end
  end

  describe "Feed.list_game_achievements/3" do
    setup %{user: user} do
      {:ok, game} = Catalog.upsert_game(%{
        platform: "retroachievements",
        external_id: "999",
        title: "Celeste",
        image_url: "https://example.com/celeste.png",
        total_achievements: 3
      })
      {:ok, ach1} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "C1", title: "The Summit", description: "Reach the top", points: 50, image_url: nil})
      {:ok, ach2} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "C2", title: "Strawberry Jam", description: nil, points: 25, image_url: nil})
      {:ok, ach3} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "C3", title: "Pico Peak", description: "No death run", points: 75, image_url: nil})

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      earlier = DateTime.add(now, -3600, :second)

      Catalog.upsert_user_game(%{user_id: user.id, game_id: game.id, unlocked_count: 2,
        is_beaten: false, is_mastered: false, last_synced_at: now})

      # ach1 and ach2 unlocked; ach3 locked
      Catalog.insert_user_achievements([
        %{user_id: user.id, achievement_id: ach1.id, unlocked_at: now},
        %{user_id: user.id, achievement_id: ach2.id, unlocked_at: earlier}
      ])

      %{game: game, ach1: ach1, ach2: ach2, ach3: ach3}
    end

    test "returns {:error, :not_found} when game does not exist", %{user: user} do
      assert {:error, :not_found} = Feed.list_game_achievements(user.id, "retroachievements", "nonexistent")
    end

    test "returns {:error, :not_found} when user has no UserGame for this game", %{game: game} do
      {:ok, other} = Accounts.register_user(%{username: "other_ach", email: "other_ach@example.com", password: "secret123"})
      assert {:error, :not_found} = Feed.list_game_achievements(other.id, game.platform, game.external_id)
    end

    test "returns {:ok, %{game, items}} with all achievements for the game", %{user: user, game: game} do
      assert {:ok, %{game: returned_game, items: items}} =
               Feed.list_game_achievements(user.id, game.platform, game.external_id)

      assert returned_game.title == "Celeste"
      assert length(items) == 3
    end

    test "marks unlocked achievements correctly", %{user: user, game: game, ach1: ach1, ach3: ach3} do
      {:ok, %{items: items}} = Feed.list_game_achievements(user.id, game.platform, game.external_id)
      by_id = Map.new(items, &{&1.achievement_id, &1})

      assert by_id[ach1.id].unlocked == true
      assert by_id[ach1.id].unlocked_at != nil
      assert by_id[ach3.id].unlocked == false
      assert by_id[ach3.id].unlocked_at == nil
    end

    test "orders unlocked before locked, then by unlocked_at desc, then points desc", %{user: user, game: game, ach1: ach1, ach2: ach2, ach3: ach3} do
      {:ok, %{items: items}} = Feed.list_game_achievements(user.id, game.platform, game.external_id)
      ids = Enum.map(items, & &1.achievement_id)
      # ach1 unlocked most recently → first
      # ach2 unlocked earlier → second
      # ach3 locked → last
      assert ids == [ach1.id, ach2.id, ach3.id]
    end

    test "returns correct achievement fields", %{user: user, game: game, ach1: ach1} do
      {:ok, %{items: items}} = Feed.list_game_achievements(user.id, game.platform, game.external_id)
      item = Enum.find(items, &(&1.achievement_id == ach1.id))
      assert item.title == "The Summit"
      assert item.description == "Reach the top"
      assert item.points == 50
    end
  end
end
