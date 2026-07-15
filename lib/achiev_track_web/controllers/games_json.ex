defmodule AchievTrackWeb.GamesJSON do
  def index(%{games: games}) do
    Enum.map(games, fn g ->
      %{
        user_game_id: g.user_game_id,
        game_id: g.game_id,
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

  def platforms(%{platforms: platforms}) do
    %{platforms: platforms}
  end

  def achievements(%{game: game, items: items}) do
    %{
      game: %{
        title: game.title,
        platform: game.platform,
        external_id: game.external_id,
        image_url: game.image_url,
        total_achievements: game.total_achievements,
        playtime_forever: game.playtime_forever,
        is_mastered: game.is_mastered
      },
      items: Enum.map(items, fn a ->
        %{
          achievement_id: a.achievement_id,
          title: a.title,
          description: a.description,
          points: a.points,
          image_url: a.image_url,
          unlocked: a.unlocked,
          unlocked_at: format_dt(a.unlocked_at),
          rarity_pct: to_float(a.rarity_pct)
        }
      end)
    }
  end

  defp format_dt(nil), do: nil
  defp format_dt(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp to_float(nil), do: nil
  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(v) when is_number(v), do: v / 1
end
