defmodule AchievTrackWeb.AchievementsJSON do
  def index(%{result: %{items: items, total: total, page: page, per_page: per_page}}) do
    %{
      total: total,
      page: page,
      per_page: per_page,
      items: Enum.map(items, fn a ->
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
    }
  end
end
