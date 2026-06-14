defmodule AchievTrackWeb.ProfileJSON do
  def show(%{user: user, stats: stats, sync_status: sync_status}) do
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
      }
    }
  end

  defp format_dt(nil), do: nil
  defp format_dt(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp format_naive_dt(nil), do: nil
  defp format_naive_dt(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
end
