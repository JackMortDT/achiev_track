defmodule AchievTrackWeb.AchievementsJSON do
  def index(%{result: %{items: items, total: total, page: page, per_page: per_page}}) do
    %{
      total: total,
      page: page,
      per_page: per_page,
      items: Enum.map(items, fn a ->
        %{
          user_achievement_id: a.user_achievement_id,
          unlocked_at: format_dt(a.unlocked_at),
          achievement_id: a.achievement_id,
          title: a.title,
          description: a.description,
          points: a.points,
          image_url: a.image_url,
          game_title: a.game_title,
          platform: a.platform,
          game_external_id: a.game_external_id
        }
      end)
    }
  end

  defp format_dt(nil), do: nil
  defp format_dt(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
