defmodule AchievTrack.CatalogTest do
  use AchievTrack.DataCase

  alias AchievTrack.Catalog
  alias AchievTrack.Accounts

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "catalog_user",
      email: "catalog@example.com",
      password: "secret123"
    })
    %{user: user}
  end

  describe "Catalog.upsert_game/1" do
    test "inserts a new game" do
      attrs = %{platform: "steam", external_id: "440", title: "Team Fortress 2",
                image_url: "https://example.com/tf2.jpg", total_achievements: 520}
      assert {:ok, game} = Catalog.upsert_game(attrs)
      assert game.title == "Team Fortress 2"
      assert game.platform == "steam"
      assert is_binary(game.id)
    end

    test "updates existing game on duplicate platform+external_id" do
      attrs = %{platform: "steam", external_id: "440", title: "TF2 Old", total_achievements: 500}
      {:ok, _} = Catalog.upsert_game(attrs)
      attrs2 = %{platform: "steam", external_id: "440", title: "Team Fortress 2", total_achievements: 520}
      assert {:ok, game} = Catalog.upsert_game(attrs2)
      assert game.title == "Team Fortress 2"
      assert game.total_achievements == 520
    end
  end

  describe "Catalog.upsert_achievement/1" do
    setup do
      {:ok, game} = Catalog.upsert_game(%{platform: "steam", external_id: "440", title: "TF2", total_achievements: 1})
      %{game: game}
    end

    test "inserts a new achievement", %{game: game} do
      attrs = %{game_id: game.id, external_id: "ACH_1", title: "First Blood",
                description: "Kill an enemy.", points: 10}
      assert {:ok, ach} = Catalog.upsert_achievement(attrs)
      assert ach.title == "First Blood"
      assert ach.game_id == game.id
    end

    test "updates existing achievement on duplicate game_id+external_id", %{game: game} do
      attrs = %{game_id: game.id, external_id: "ACH_1", title: "Old Name", points: 5}
      {:ok, _} = Catalog.upsert_achievement(attrs)
      attrs2 = %{game_id: game.id, external_id: "ACH_1", title: "First Blood", points: 10}
      assert {:ok, ach} = Catalog.upsert_achievement(attrs2)
      assert ach.title == "First Blood"
      assert ach.points == 10
    end
  end

  describe "Catalog.upsert_user_game/1" do
    setup do
      {:ok, game} = Catalog.upsert_game(%{platform: "steam", external_id: "440", title: "TF2", total_achievements: 10})
      %{game: game}
    end

    test "inserts user_game", %{user: user, game: game} do
      attrs = %{user_id: user.id, game_id: game.id, unlocked_count: 3,
                is_beaten: false, is_mastered: false,
                last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second)}
      assert {:ok, ug} = Catalog.upsert_user_game(attrs)
      assert ug.unlocked_count == 3
    end

    test "updates progress on re-sync", %{user: user, game: game} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      attrs = %{user_id: user.id, game_id: game.id, unlocked_count: 3,
                is_beaten: false, is_mastered: false, last_synced_at: now}
      {:ok, _} = Catalog.upsert_user_game(attrs)
      attrs2 = Map.put(attrs, :unlocked_count, 10)
      assert {:ok, ug} = Catalog.upsert_user_game(attrs2)
      assert ug.unlocked_count == 10
    end
  end

  describe "Catalog.insert_user_achievements/1" do
    setup do
      {:ok, game} = Catalog.upsert_game(%{platform: "steam", external_id: "440", title: "TF2", total_achievements: 2})
      {:ok, ach1} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "A1", title: "Ach1", points: 5})
      {:ok, ach2} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "A2", title: "Ach2", points: 5})
      %{ach1: ach1, ach2: ach2}
    end

    test "inserts new user_achievements and returns count", %{user: user, ach1: ach1, ach2: ach2} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      rows = [
        %{user_id: user.id, achievement_id: ach1.id, unlocked_at: now},
        %{user_id: user.id, achievement_id: ach2.id, unlocked_at: now}
      ]
      assert {2, _} = Catalog.insert_user_achievements(rows)
    end

    test "skips duplicates and returns only new count", %{user: user, ach1: ach1, ach2: ach2} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      rows = [%{user_id: user.id, achievement_id: ach1.id, unlocked_at: now}]
      {1, _} = Catalog.insert_user_achievements(rows)

      rows2 = [
        %{user_id: user.id, achievement_id: ach1.id, unlocked_at: now},
        %{user_id: user.id, achievement_id: ach2.id, unlocked_at: now}
      ]
      assert {1, _} = Catalog.insert_user_achievements(rows2)
    end
  end

  describe "Catalog.get_achievement_ids_for_user/1" do
    setup do
      {:ok, game} = Catalog.upsert_game(%{platform: "steam", external_id: "999", title: "Game", total_achievements: 2})
      {:ok, ach1} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "B1", title: "B1", points: 5})
      {:ok, ach2} = Catalog.upsert_achievement(%{game_id: game.id, external_id: "B2", title: "B2", points: 5})
      %{ach1: ach1, ach2: ach2}
    end

    test "returns ids for user's unlocked achievements", %{user: user, ach1: ach1, ach2: ach2} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Catalog.insert_user_achievements([
        %{user_id: user.id, achievement_id: ach1.id, unlocked_at: now}
      ])
      ids = Catalog.get_achievement_ids_for_user(user.id)
      assert ach1.id in ids
      refute ach2.id in ids
    end

    test "returns empty list for user with no achievements", %{user: user} do
      assert Catalog.get_achievement_ids_for_user(user.id) == []
    end

    test "does not return achievements unlocked by other users", %{user: user, ach1: ach1} do
      {:ok, other_user} = AchievTrack.Accounts.register_user(%{
        username: "other_user",
        email: "other@example.com",
        password: "secret123"
      })
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Catalog.insert_user_achievements([
        %{user_id: other_user.id, achievement_id: ach1.id, unlocked_at: now}
      ])
      assert Catalog.get_achievement_ids_for_user(user.id) == []
    end
  end
end
