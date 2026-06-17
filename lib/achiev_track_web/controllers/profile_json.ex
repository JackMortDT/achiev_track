defmodule AchievTrackWeb.ProfileJSON do
  def show(%{user: user, stats: stats, sync_status: sync_status, customization: customization}) do
    %{
      user: %{
        id: user.id,
        username: user.username,
        email: user.email,
        avatar_url: user.avatar_url,
        inserted_at: format_naive_dt(user.inserted_at)
      },
      stats: %{
        total_achievements: stats.total_achievements,
        total_games: stats.total_games,
        total_points: stats.total_points
      },
      platforms: Enum.map(user.platform_connections, fn pc ->
        %{platform: pc.platform, external_id: pc.external_id, connected_at: format_naive_dt(pc.inserted_at)}
      end),
      sync_status: %{
        allowed: sync_status.allowed,
        syncs_used: sync_status.syncs_used,
        syncs_remaining: sync_status.syncs_remaining,
        next_available_at: format_dt(sync_status.next_available_at)
      },
      customization: %{
        favorite_game: format_showcase_game(customization.favorite_game),
        game_showcase: Enum.map(customization.game_showcase, &format_showcase_game/1),
        achievement_showcase: Enum.map(customization.achievement_showcase, &format_showcase_achievement/1)
      }
    }
  end

  defp format_showcase_game(nil), do: nil
  defp format_showcase_game(g) do
    base = %{
      id: g.id,
      title: g.title,
      image_url: g.image_url,
      platform: g.platform,
      unlocked_count: g.unlocked_count,
      total_achievements: g.total_achievements,
      playtime_forever: g.playtime_forever
    }
    case Map.fetch(g, :position) do
      {:ok, pos} -> Map.put(base, :position, pos)
      :error -> base
    end
  end

  defp format_showcase_achievement(a) do
    %{
      id: a.id,
      name: a.name,
      description: a.description,
      image_url: a.image_url,
      game_title: a.game_title,
      unlocked_at: format_dt(a.unlocked_at),
      points: a.points,
      position: a.position
    }
  end

  defp format_dt(nil), do: nil
  defp format_dt(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp format_naive_dt(nil), do: nil
  defp format_naive_dt(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
end
