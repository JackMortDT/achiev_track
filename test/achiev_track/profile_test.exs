defmodule AchievTrack.ProfileTest do
  use AchievTrack.DataCase

  alias AchievTrack.{Profile, Accounts, Catalog, Repo}
  alias AchievTrack.Catalog.{Achievement, UserAchievement}

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "prof_user",
      email: "prof@example.com",
      password: "secret123"
    })
    {:ok, game} = Catalog.upsert_game(%{
      platform: "steam", external_id: "440", title: "TF2", total_achievements: 5
    })
    Catalog.upsert_user_game(%{
      user_id: user.id, game_id: game.id,
      unlocked_count: 3, is_beaten: false, is_mastered: false,
      playtime_forever: 100,
      last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    {:ok, achievement} = Repo.insert(
      Achievement.changeset(%Achievement{}, %{
        game_id: game.id, external_id: "ACH_1", title: "First Blood",
        description: "Kill someone", points: 50
      })
    )
    {:ok, ua} = Repo.insert(
      UserAchievement.changeset(%UserAchievement{}, %{
        user_id: user.id, achievement_id: achievement.id,
        unlocked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
    )
    %{user: user, game: game, ua: ua}
  end

  describe "get_profile_customization/1" do
    test "returns empty customization for new user", %{user: user} do
      result = Profile.get_profile_customization(user.id)
      assert result.favorite_game == nil
      assert result.game_showcase == []
      assert result.achievement_showcase == []
    end
  end

  describe "set_favorite_game/2" do
    test "sets favorite game when game belongs to user", %{user: user, game: game} do
      assert {:ok, _} = Profile.set_favorite_game(user.id, game.id)
      result = Profile.get_profile_customization(user.id)
      assert result.favorite_game.id == game.id
      assert result.favorite_game.title == "TF2"
      assert result.favorite_game.unlocked_count == 3
      assert result.favorite_game.playtime_forever == 100
    end

    test "returns error when game is not in user library", %{user: user} do
      {:ok, other} = Catalog.upsert_game(%{
        platform: "steam", external_id: "999", title: "Other", total_achievements: 0
      })
      assert {:error, :game_not_found} = Profile.set_favorite_game(user.id, other.id)
    end

    test "clears favorite game when nil", %{user: user, game: game} do
      Profile.set_favorite_game(user.id, game.id)
      assert {:ok, _} = Profile.set_favorite_game(user.id, nil)
      assert Profile.get_profile_customization(user.id).favorite_game == nil
    end
  end

  describe "set_game_showcase/2" do
    test "sets showcase in given order", %{user: user, game: game} do
      {:ok, game2} = Catalog.upsert_game(%{
        platform: "steam", external_id: "730", title: "CS2", total_achievements: 0
      })
      Catalog.upsert_user_game(%{
        user_id: user.id, game_id: game2.id,
        unlocked_count: 0, is_beaten: false, is_mastered: false,
        playtime_forever: 0,
        last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      assert {:ok, _} = Profile.set_game_showcase(user.id, [game.id, game2.id])
      showcase = Profile.get_profile_customization(user.id).game_showcase
      assert length(showcase) == 2
      assert Enum.at(showcase, 0).id == game.id
      assert Enum.at(showcase, 1).id == game2.id
      assert Enum.at(showcase, 0).position == 0
    end

    test "returns error for more than 6 games", %{user: user, game: game} do
      assert {:error, :too_many_games} =
        Profile.set_game_showcase(user.id, List.duplicate(game.id, 7))
    end

    test "returns error when a game is not owned", %{user: user} do
      {:ok, other} = Catalog.upsert_game(%{
        platform: "steam", external_id: "111", title: "Unknown", total_achievements: 0
      })
      assert {:error, :game_not_found} = Profile.set_game_showcase(user.id, [other.id])
    end

    test "replaces entire showcase on update", %{user: user, game: game} do
      Profile.set_game_showcase(user.id, [game.id])
      assert {:ok, _} = Profile.set_game_showcase(user.id, [])
      assert Profile.get_profile_customization(user.id).game_showcase == []
    end
  end

  describe "set_achievement_showcase/2" do
    test "sets achievement showcase in given order", %{user: user, ua: ua} do
      assert {:ok, _} = Profile.set_achievement_showcase(user.id, [ua.id])
      showcase = Profile.get_profile_customization(user.id).achievement_showcase
      assert length(showcase) == 1
      assert Enum.at(showcase, 0).id == ua.id
      assert Enum.at(showcase, 0).name == "First Blood"
      assert Enum.at(showcase, 0).points == 50
      assert Enum.at(showcase, 0).game_title == "TF2"
      assert Enum.at(showcase, 0).position == 0
    end

    test "returns error for more than 5 achievements", %{user: user, ua: ua} do
      assert {:error, :too_many_achievements} =
        Profile.set_achievement_showcase(user.id, List.duplicate(ua.id, 6))
    end

    test "returns error when achievement does not belong to user", %{user: user} do
      fake_id = Ecto.UUID.generate()
      assert {:error, :achievement_not_found} =
        Profile.set_achievement_showcase(user.id, [fake_id])
    end

    test "replaces entire achievement showcase on update", %{user: user, ua: ua} do
      Profile.set_achievement_showcase(user.id, [ua.id])
      assert {:ok, _} = Profile.set_achievement_showcase(user.id, [])
      assert Profile.get_profile_customization(user.id).achievement_showcase == []
    end
  end
end
