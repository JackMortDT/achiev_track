defmodule AchievTrack.Repo.Migrations.AddEmailVerificationToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :email_verified_at, :utc_datetime, null: true
      add :email_verification_token, :string, null: true
      add :email_verification_sent_at, :utc_datetime, null: true
    end
  end
end
