defmodule AchievTrack.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :platform, :string, null: false
      add :external_id, :string, null: false
      add :title, :string, null: false
      add :image_url, :string
      add :total_achievements, :integer, default: 0

      timestamps()
    end

    create unique_index(:games, [:platform, :external_id])
  end
end
