defmodule AchievTrackWeb.HomeJSON do
  def index(%{data: data}) do
    %{
      stats: data.stats,
      recent_achievements: Enum.map(data.recent_achievements, &achievement_data/1),
      active_games: Enum.map(data.active_games, &game_data/1),
      popular_games: Enum.map(data.popular_games, &popular_game_data/1)
    }
  end

  defp achievement_data(a) do
    %{
      achievement_id: a.achievement_id,
      title: a.title,
      description: a.description,
      points: a.points,
      image_url: a.image_url,
      game_title: a.game_title,
      platform: a.platform,
      game_external_id: a.game_external_id,
      unlocked_at: format_dt(a.unlocked_at)
    }
  end

  defp game_data(g) do
    %{
      title: g.title,
      platform: g.platform,
      external_id: g.external_id,
      image_url: g.image_url,
      total_achievements: g.total_achievements,
      unlocked_count: g.unlocked_count,
      is_beaten: g.is_beaten,
      is_mastered: g.is_mastered
    }
  end

  defp popular_game_data(g) do
    %{
      title: g.title,
      platform: g.platform,
      external_id: g.external_id,
      image_url: g.image_url,
      total_achievements: g.total_achievements,
      player_count: g.player_count
    }
  end

  defp format_dt(nil), do: nil
  defp format_dt(dt), do: DateTime.to_iso8601(dt)
end
