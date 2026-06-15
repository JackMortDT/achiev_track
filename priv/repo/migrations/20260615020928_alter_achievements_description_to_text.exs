defmodule AchievTrack.Repo.Migrations.AlterAchievementsDescriptionToText do
  use Ecto.Migration

  def change do
    alter table(:achievements) do
      modify :description, :text
    end
  end
end
