defmodule AchievTrackWeb.GamesJSON do
  def index(%{games: games}) do
    Enum.map(games, fn g ->
      %{
        user_game_id: g.user_game_id,
        title: g.title,
        platform: g.platform,
        external_id: g.external_id,
        image_url: g.image_url,
        total_achievements: g.total_achievements,
        unlocked_count: g.unlocked_count,
        is_beaten: g.is_beaten,
        is_mastered: g.is_mastered,
        last_synced_at: format_dt(g.last_synced_at)
      }
    end)
  end

  defp format_dt(nil), do: nil
  defp format_dt(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
