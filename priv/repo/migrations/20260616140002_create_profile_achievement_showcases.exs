defmodule AchievTrack.Repo.Migrations.CreateProfileAchievementShowcases do
  use Ecto.Migration

  def change do
    create table(:profile_achievement_showcases, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :user_achievement_id, references(:user_achievements, type: :uuid, on_delete: :delete_all), null: false
      add :position, :integer, null: false
      timestamps()
    end

    create unique_index(:profile_achievement_showcases, [:user_id, :position])
    create unique_index(:profile_achievement_showcases, [:user_id, :user_achievement_id])
  end
end
