defmodule AchievTrack.Catalog.ProfileGameShowcase do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profile_game_showcases" do
    field :position, :integer
    belongs_to :user, AchievTrack.Accounts.User
    belongs_to :game, AchievTrack.Catalog.Game
    timestamps()
  end

  def changeset(s, attrs) do
    s
    |> cast(attrs, [:user_id, :game_id, :position])
    |> validate_required([:user_id, :game_id, :position])
    |> validate_number(:position, greater_than_or_equal_to: 0, less_than: 6)
    |> unique_constraint([:user_id, :position])
    |> unique_constraint([:user_id, :game_id])
  end
end
