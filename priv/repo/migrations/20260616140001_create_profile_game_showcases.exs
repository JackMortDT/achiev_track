defmodule AchievTrack.Repo.Migrations.CreateProfileGameShowcases do
  use Ecto.Migration

  def change do
    create table(:profile_game_showcases, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :game_id, references(:games, type: :uuid, on_delete: :delete_all), null: false
      add :position, :integer, null: false
      timestamps()
    end

    create unique_index(:profile_game_showcases, [:user_id, :position])
    create unique_index(:profile_game_showcases, [:user_id, :game_id])
  end
end
