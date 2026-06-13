defmodule AchievTrack.Repo.Migrations.CreateUserGames do
  use Ecto.Migration

  def change do
    create table(:user_games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :unlocked_count, :integer, default: 0
      add :is_beaten, :boolean, default: false
      add :is_mastered, :boolean, default: false
      add :last_synced_at, :utc_datetime

      timestamps()
    end

    create unique_index(:user_games, [:user_id, :game_id])
    create index(:user_games, [:user_id])
  end
end
