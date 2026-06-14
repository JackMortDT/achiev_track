defmodule AchievTrackWeb.AchievementsJSON do
  def index(%{achievements: achievements}) do
    Enum.map(achievements, fn a ->
      %{
        unlocked_at: a.unlocked_at,
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
  end
end
