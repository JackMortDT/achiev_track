defmodule AchievTrack.Profile do
  import Ecto.Query
  alias AchievTrack.Repo
  alias AchievTrack.Accounts.User
  alias AchievTrack.Catalog.{
    Game, UserGame, Achievement, UserAchievement,
    ProfileGameShowcase, ProfileAchievementShowcase
  }

  def get_profile_customization(user_id) do
    %{
      favorite_game: get_favorite_game(user_id),
      game_showcase: get_game_showcase(user_id),
      achievement_showcase: get_achievement_showcase(user_id)
    }
  end

  defp get_favorite_game(user_id) do
    Repo.one(
      from u in User,
      where: u.id == ^user_id and not is_nil(u.favorite_game_id),
      join: g in assoc(u, :favorite_game),
      left_join: ug in UserGame, on: ug.game_id == g.id and ug.user_id == ^user_id,
      select: %{
        id: g.id,
        title: g.title,
        image_url: g.image_url,
        platform: g.platform,
        unlocked_count: coalesce(ug.unlocked_count, 0),
        total_achievements: g.total_achievements,
        playtime_forever: coalesce(ug.playtime_forever, 0)
      }
    )
  end

  defp get_game_showcase(user_id) do
    Repo.all(
      from pgs in ProfileGameShowcase,
      where: pgs.user_id == ^user_id,
      join: g in assoc(pgs, :game),
      left_join: ug in UserGame, on: ug.game_id == g.id and ug.user_id == ^user_id,
      order_by: pgs.position,
      select: %{
        id: g.id,
        title: g.title,
        image_url: g.image_url,
        platform: g.platform,
        unlocked_count: coalesce(ug.unlocked_count, 0),
        total_achievements: g.total_achievements,
        playtime_forever: coalesce(ug.playtime_forever, 0),
        position: pgs.position
      }
    )
  end

  defp get_achievement_showcase(user_id) do
    Repo.all(
      from pas in ProfileAchievementShowcase,
      where: pas.user_id == ^user_id,
      join: ua in assoc(pas, :user_achievement),
      join: a in Achievement, on: a.id == ua.achievement_id,
      join: g in Game, on: g.id == a.game_id,
      order_by: pas.position,
      select: %{
        id: ua.id,
        name: a.title,
        description: a.description,
        image_url: a.image_url,
        game_title: g.title,
        unlocked_at: ua.unlocked_at,
        points: a.points,
        position: pas.position
      }
    )
  end

  def set_favorite_game(user_id, nil) do
    Repo.get!(User, user_id)
    |> User.favorite_game_changeset(%{favorite_game_id: nil})
    |> Repo.update()
  end

  def set_favorite_game(user_id, game_id) do
    owned = Repo.one(from ug in UserGame,
      where: ug.user_id == ^user_id and ug.game_id == ^game_id)
    case owned do
      nil -> {:error, :game_not_found}
      _ ->
        Repo.get!(User, user_id)
        |> User.favorite_game_changeset(%{favorite_game_id: game_id})
        |> Repo.update()
    end
  end

  def set_game_showcase(_user_id, game_ids) when length(game_ids) > 6,
    do: {:error, :too_many_games}

  def set_game_showcase(user_id, game_ids) do
    owned = Repo.all(from ug in UserGame,
      where: ug.user_id == ^user_id and ug.game_id in ^game_ids,
      select: ug.game_id)
    if length(owned) < length(game_ids) do
      {:error, :game_not_found}
    else
      Repo.transaction(fn ->
        Repo.delete_all(from pgs in ProfileGameShowcase, where: pgs.user_id == ^user_id)
        game_ids |> Enum.with_index() |> Enum.each(fn {gid, pos} ->
          %ProfileGameShowcase{}
          |> ProfileGameShowcase.changeset(%{user_id: user_id, game_id: gid, position: pos})
          |> Repo.insert!()
        end)
      end)
    end
  end

  def set_achievement_showcase(_user_id, ua_ids) when length(ua_ids) > 5,
    do: {:error, :too_many_achievements}

  def set_achievement_showcase(user_id, ua_ids) do
    valid = Repo.all(from ua in UserAchievement,
      where: ua.user_id == ^user_id and ua.id in ^ua_ids,
      select: ua.id)
    if length(valid) < length(ua_ids) do
      {:error, :achievement_not_found}
    else
      Repo.transaction(fn ->
        Repo.delete_all(from pas in ProfileAchievementShowcase, where: pas.user_id == ^user_id)
        ua_ids |> Enum.with_index() |> Enum.each(fn {ua_id, pos} ->
          %ProfileAchievementShowcase{}
          |> ProfileAchievementShowcase.changeset(%{
            user_id: user_id,
            user_achievement_id: ua_id,
            position: pos
          })
          |> Repo.insert!()
        end)
      end)
    end
  end
end
