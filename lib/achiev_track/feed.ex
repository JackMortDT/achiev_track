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

  @per_page 100

  def list_user_achievements(user_id, opts \\ []) do
    platform = Keyword.get(opts, :platform)
    sort = Keyword.get(opts, :sort, "date")
    page = max(Keyword.get(opts, :page, 1), 1)
    per_page = min(Keyword.get(opts, :per_page, @per_page), 200)

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

    sorted =
      case sort do
        "points" -> order_by(query, [_ua, a], desc: a.points)
        "game" -> order_by(query, [_ua, a, g], asc: g.title, asc: a.title)
        _ -> order_by(query, [ua], desc: ua.unlocked_at)
      end

    total = Repo.aggregate(query, :count)
    items = sorted |> offset(^((page - 1) * per_page)) |> limit(^per_page) |> Repo.all()

    %{items: items, total: total, page: page, per_page: per_page}
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

  def friends_leaderboard(user_id) do
    friend_ids = get_friend_ids(user_id)
    all_ids = [user_id | friend_ids]

    Repo.all(
      from u in AchievTrack.Accounts.User,
        left_join: ua in UserAchievement, on: ua.user_id == u.id,
        left_join: a in Achievement, on: a.id == ua.achievement_id,
        where: u.id in ^all_ids,
        group_by: [u.id, u.username, u.avatar_url],
        select: %{
          user_id: u.id,
          username: u.username,
          avatar_url: u.avatar_url,
          total_points: coalesce(sum(a.points), 0)
        },
        order_by: [desc: coalesce(sum(a.points), 0)]
    )
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, rank} -> Map.put(entry, :rank, rank) end)
  end

  def compare_with_friend(user_id, friend_id) do
    user_stats = get_user_stats(user_id)
    friend_stats = get_user_stats(friend_id)
    friend = Repo.get!(AchievTrack.Accounts.User, friend_id)

    shared_games =
      Repo.all(
        from ug1 in UserGame,
          join: ug2 in UserGame,
            on: ug1.game_id == ug2.game_id and ug2.user_id == ^friend_id,
          join: g in Game, on: g.id == ug1.game_id,
          where: ug1.user_id == ^user_id,
          select: %{
            title: g.title,
            platform: g.platform,
            user_unlocked: ug1.unlocked_count,
            friend_unlocked: ug2.unlocked_count,
            total: g.total_achievements
          },
          order_by: [desc: ug1.unlocked_count]
      )

    %{
      user: user_stats,
      friend: %{
        username: friend.username,
        total_achievements: friend_stats.total_achievements,
        total_games: friend_stats.total_games,
        total_points: friend_stats.total_points
      },
      shared_games: shared_games
    }
  end

  def list_game_achievements(user_id, platform, external_id) do
    game = Repo.one(from g in Game,
      where: g.platform == ^platform and g.external_id == ^external_id)

    if is_nil(game) do
      {:error, :not_found}
    else
      user_game = Repo.one(from ug in UserGame,
        where: ug.user_id == ^user_id and ug.game_id == ^game.id)

      if is_nil(user_game) do
        {:error, :not_found}
      else
        items =
          Repo.all(
            from a in Achievement,
              left_join: ua in UserAchievement,
                on: ua.achievement_id == a.id and ua.user_id == ^user_id,
              where: a.game_id == ^game.id,
              order_by: [
                asc: is_nil(ua.id),
                desc_nulls_last: ua.unlocked_at,
                desc: a.points
              ],
              select: %{
                achievement_id: a.id,
                title: a.title,
                description: a.description,
                points: a.points,
                image_url: a.image_url,
                unlocked: not is_nil(ua.id),
                unlocked_at: ua.unlocked_at
              }
          )

        {:ok, %{
          game: %{
            title: game.title,
            platform: game.platform,
            external_id: game.external_id,
            image_url: game.image_url,
            total_achievements: game.total_achievements
          },
          items: items
        }}
      end
    end
  end

  defp get_friend_ids(user_id) do
    alias AchievTrack.Accounts.Friendship

    as_requester =
      Repo.all(
        from f in Friendship,
          where: f.requester_id == ^user_id and f.status == "accepted",
          select: f.addressee_id
      )

    as_addressee =
      Repo.all(
        from f in Friendship,
          where: f.addressee_id == ^user_id and f.status == "accepted",
          select: f.requester_id
      )

    as_requester ++ as_addressee
  end
end
