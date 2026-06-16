defmodule AchievTrack.Catalog.UserGame do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_games" do
    field :unlocked_count, :integer, default: 0
    field :is_beaten, :boolean, default: false
    field :is_mastered, :boolean, default: false
    field :last_synced_at, :utc_datetime
    field :playtime_forever, :integer, default: 0

    belongs_to :user, AchievTrack.Accounts.User
    belongs_to :game, AchievTrack.Catalog.Game

    timestamps()
  end

  def changeset(user_game, attrs) do
    user_game
    |> cast(attrs, [:user_id, :game_id, :unlocked_count, :is_beaten, :is_mastered, :last_synced_at, :playtime_forever])
    |> validate_required([:user_id, :game_id])
  end
end
