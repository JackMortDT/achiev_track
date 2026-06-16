defmodule AchievTrack.Repo.Migrations.AddPlaytimeToUserGames do
  use Ecto.Migration

  def change do
    alter table(:user_games) do
      add :playtime_forever, :integer, default: 0, null: false
    end
  end
end
