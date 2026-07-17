defmodule AchievTrack.Repo.Migrations.OauthChanges do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :email, :string, null: true, from: {:string, null: false}
      modify :password_hash, :string, null: true, from: {:string, null: false}
      add :google_id, :string, null: true
    end

    create unique_index(:users, [:google_id])
  end
end
