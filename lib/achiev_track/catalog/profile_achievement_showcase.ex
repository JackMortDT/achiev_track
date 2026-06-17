defmodule AchievTrack.Catalog.ProfileAchievementShowcase do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profile_achievement_showcases" do
    field :position, :integer
    belongs_to :user, AchievTrack.Accounts.User
    belongs_to :user_achievement, AchievTrack.Catalog.UserAchievement
    timestamps()
  end

  def changeset(s, attrs) do
    s
    |> cast(attrs, [:user_id, :user_achievement_id, :position])
    |> validate_required([:user_id, :user_achievement_id, :position])
    |> validate_number(:position, greater_than_or_equal_to: 0, less_than: 5)
    |> unique_constraint([:user_id, :position])
    |> unique_constraint([:user_id, :user_achievement_id])
  end
end
