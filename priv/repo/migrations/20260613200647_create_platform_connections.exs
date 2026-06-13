defmodule AchievTrack.Repo.Migrations.CreatePlatformConnections do
  use Ecto.Migration

  def change do
    create table(:platform_connections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :platform, :string, null: false
      add :external_id, :string, null: false
      add :api_key, :string

      timestamps()
    end

    create unique_index(:platform_connections, [:user_id, :platform])
    create index(:platform_connections, [:user_id])
  end
end
