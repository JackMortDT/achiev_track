defmodule AchievTrack.Repo.Migrations.EncryptPlatformConnectionApiKeys do
  use Ecto.Migration

  def up do
    alter table(:platform_connections) do
      modify :api_key, :text
    end
    # Existing plaintext keys are wiped — users must reconnect their platforms.
    # This avoids running app code inside a migration to encrypt existing values.
    execute "UPDATE platform_connections SET api_key = NULL"
  end

  def down do
    alter table(:platform_connections) do
      modify :api_key, :string
    end
  end
end
