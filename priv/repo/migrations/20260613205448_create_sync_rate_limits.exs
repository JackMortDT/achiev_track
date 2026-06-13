defmodule AchievTrack.Repo.Migrations.CreateSyncRateLimits do
  use Ecto.Migration

  def change do
    create table(:sync_rate_limits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :synced_at, :utc_datetime, null: false
    end

    create index(:sync_rate_limits, [:user_id])
    create index(:sync_rate_limits, [:synced_at])
  end
end
