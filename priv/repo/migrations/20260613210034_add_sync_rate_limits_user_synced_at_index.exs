defmodule AchievTrack.Repo.Migrations.AddSyncRateLimitsUserSyncedAtIndex do
  use Ecto.Migration

  def change do
    create index(:sync_rate_limits, [:user_id, :synced_at])
  end
end
