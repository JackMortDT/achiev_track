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
          user_achievement_id: ua.id,
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

  def list_user_games(user_id, status) when is_binary(status) do
    list_user_games(user_id, status: status)
  end

  def list_user_games(user_id, opts \\ []) when is_list(opts) do
    status = Keyword.get(opts, :status, "all")
    platform = Keyword.get(opts, :platform)

    last_achieved_subq =
      from ua in UserAchievement,
        join: a in Achievement, on: a.id == ua.achievement_id,
        where: ua.user_id == ^user_id,
        group_by: a.game_id,
        select: %{game_id: a.game_id, last_at: max(ua.unlocked_at)}

    base =
      from ug in UserGame,
        join: g in Game, on: g.id == ug.game_id,
        left_join: last in subquery(last_achieved_subq), on: last.game_id == g.id,
        where: ug.user_id == ^user_id,
        order_by: [desc_nulls_last: last.last_at, desc: ug.unlocked_count],
        select: %{
          user_game_id: ug.id,
          game_id: g.id,
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

    base
    |> then(fn q ->
      case status do
        "mastered" -> where(q, [ug], ug.is_mastered == true)
        "beaten" -> where(q, [ug], ug.is_beaten == true and ug.is_mastered == false)
        "in_progress" -> where(q, [ug], ug.is_beaten == false)
        _ -> q
      end
    end)
    |> then(fn q -> if platform, do: where(q, [_ug, g], g.platform == ^platform), else: q end)
    |> Repo.all()
  end

  def list_user_platforms(user_id) do
    from(ug in UserGame,
      join: g in Game, on: g.id == ug.game_id,
      where: ug.user_id == ^user_id and not is_nil(g.platform),
      select: g.platform,
      distinct: true,
      order_by: g.platform
    )
    |> Repo.all()
  end

  def recent_achievements(user_id, limit) do
    from(ua in UserAchievement,
      join: a in Achievement, on: a.id == ua.achievement_id,
      join: g in Game, on: g.id == a.game_id,
      where: ua.user_id == ^user_id,
      order_by: [desc: ua.unlocked_at],
      limit: ^limit,
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
    )
    |> Repo.all()
  end

  def popular_games(limit) do
    from(ug in UserGame,
      join: g in Game, on: g.id == ug.game_id,
      group_by: [g.id, g.title, g.platform, g.external_id, g.image_url, g.total_achievements],
      order_by: [desc: count(ug.user_id)],
      limit: ^limit,
      select: %{
        title: g.title,
        platform: g.platform,
        external_id: g.external_id,
        image_url: g.image_url,
        total_achievements: g.total_achievements,
        player_count: count(ug.user_id)
      }
    )
    |> Repo.all()
  end

  def home_data(user_id) do
    stats = get_user_stats(user_id)
    leaderboard = friends_leaderboard(user_id)
    friend_rank =
      case Enum.find_index(leaderboard, &(&1.user_id == user_id)) do
        nil -> nil
        idx -> idx + 1
      end

    %{
      stats: Map.put(stats, :friend_rank, friend_rank),
      recent_achievements: recent_achievements(user_id, 5),
      active_games: list_user_games(user_id) |> Enum.take(3),
      popular_games: popular_games(4)
    }
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
