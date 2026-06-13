defmodule AchievTrack.Repo.Migrations.CreateAchievements do
  use Ecto.Migration

  def change do
    create table(:achievements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :external_id, :string, null: false
      add :title, :string, null: false
      add :description, :string
      add :points, :integer, default: 0
      add :image_url, :string

      timestamps()
    end

    create unique_index(:achievements, [:game_id, :external_id])
    create index(:achievements, [:game_id])
  end
end
