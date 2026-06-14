defmodule AchievTrack.Feed do
  import Ecto.Query
  alias AchievTrack.Repo
  alias AchievTrack.Catalog.{Achievement, UserAchievement, Game, UserGame}

  def get_user_stats(user_id) do
    total_achievements =
      Repo.aggregate(from(ua in UserAchievement, where: ua.user_id == ^user_id), :count) || 0

    total_games =
      Repo.aggregate(from(ug in UserGame, where: ug.user_id == ^user_id), :count) || 0

    total_points =
      Repo.one(
        from ua in UserAchievement,
          join: a in Achievement, on: a.id == ua.achievement_id,
          where: ua.user_id == ^user_id,
          select: coalesce(sum(a.points), 0)
      ) || 0

    %{
      total_achievements: total_achievements,
      total_games: total_games,
      total_points: total_points
    }
  end

  def list_user_achievements(user_id, opts \\ []) do
    platform = Keyword.get(opts, :platform)
    sort = Keyword.get(opts, :sort, "date")

    query =
      from ua in UserAchievement,
        join: a in Achievement, on: a.id == ua.achievement_id,
        join: g in Game, on: g.id == a.game_id,
        where: ua.user_id == ^user_id,
        select: %{
          unlocked_at: ua.unlocked_at,
          achievement_id: a.id,
          title: a.title,
          description: a.description,
          points: a.points,
          image_url: a.image_url,
          game_title: g.title,
          platform: g.platform,
          game_external_id: g.external_id
        }

    query = if platform, do: where(query, [_ua, _a, g], g.platform == ^platform), else: query

    case sort do
      "points" -> order_by(query, [_ua, a], desc: a.points)
      "game" -> order_by(query, [_ua, _a, g], asc: g.title)
      _ -> order_by(query, [ua], desc: ua.unlocked_at)
    end
    |> Repo.all()
  end

  def list_user_games(user_id, status \\ "all") do
    base =
      from ug in UserGame,
        join: g in Game, on: g.id == ug.game_id,
        where: ug.user_id == ^user_id,
        order_by: [desc: ug.unlocked_count],
        select: %{
          user_game_id: ug.id,
          unlocked_count: ug.unlocked_count,
          is_beaten: ug.is_beaten,
          is_mastered: ug.is_mastered,
          last_synced_at: ug.last_synced_at,
          title: g.title,
          platform: g.platform,
          external_id: g.external_id,
          image_url: g.image_url,
          total_achievements: g.total_achievements
        }

    case status do
      "mastered" -> where(base, [ug], ug.is_mastered == true)
      # "beaten" excludes mastered — mastered games belong in their own category
      "beaten" -> where(base, [ug], ug.is_beaten == true and ug.is_mastered == false)
      "in_progress" -> where(base, [ug], ug.is_beaten == false)
      _ -> base
    end
    |> Repo.all()
  end

  # friends_leaderboard/1 and compare_with_friend/2 are implemented in Task 3
  # once AchievTrack.Accounts.Friendship schema is available.
end
