defmodule AchievTrack.Repo.Migrations.AddFavoriteGameToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :favorite_game_id, references(:games, type: :uuid, on_delete: :nilify_all), null: true
    end
  end
end
