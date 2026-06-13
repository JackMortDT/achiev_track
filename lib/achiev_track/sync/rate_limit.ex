defmodule AchievTrack.Sync.RateLimit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sync_rate_limits" do
    field :synced_at, :utc_datetime
    belongs_to :user, AchievTrack.Accounts.User
  end

  def changeset(rl, attrs) do
    rl
    |> cast(attrs, [:user_id, :synced_at])
    |> validate_required([:user_id, :synced_at])
  end
end
