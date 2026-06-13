defmodule AchievTrack.Sync do
  import Ecto.Query
  alias AchievTrack.Repo
  alias AchievTrack.Sync.RateLimit

  @max_syncs_per_hour 3
  @window_seconds 3600

  def rate_limit_status(user_id) do
    window_start = DateTime.utc_now() |> DateTime.add(-@window_seconds, :second) |> DateTime.truncate(:second)

    recent = Repo.all(
      from rl in RateLimit,
      where: rl.user_id == ^user_id and rl.synced_at > ^window_start,
      order_by: [asc: rl.synced_at]
    )

    used = length(recent)
    remaining = max(@max_syncs_per_hour - used, 0)
    allowed = used < @max_syncs_per_hour

    next_available_at =
      if not allowed do
        oldest = List.first(recent)
        DateTime.add(oldest.synced_at, @window_seconds, :second)
      else
        nil
      end

    %{
      allowed: allowed,
      syncs_used: used,
      syncs_remaining: remaining,
      next_available_at: next_available_at
    }
  end

  def record_sync(user_id, synced_at \\ nil) do
    at = if is_nil(synced_at), do: DateTime.utc_now() |> DateTime.truncate(:second), else: synced_at

    %RateLimit{}
    |> RateLimit.changeset(%{user_id: user_id, synced_at: at})
    |> Repo.insert()
  end
end
