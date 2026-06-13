defmodule AchievTrack.Catalog.Achievement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "achievements" do
    field :external_id, :string
    field :title, :string
    field :description, :string
    field :points, :integer, default: 0
    field :image_url, :string

    belongs_to :game, AchievTrack.Catalog.Game

    timestamps()
  end

  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, [:game_id, :external_id, :title, :description, :points, :image_url])
    |> validate_required([:game_id, :external_id, :title])
  end
end
