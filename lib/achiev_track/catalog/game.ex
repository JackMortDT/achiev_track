defmodule AchievTrack.Catalog.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "games" do
    field :platform, :string
    field :external_id, :string
    field :title, :string
    field :image_url, :string
    field :total_achievements, :integer, default: 0

    has_many :achievements, AchievTrack.Catalog.Achievement

    timestamps()
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [:platform, :external_id, :title, :image_url, :total_achievements])
    |> validate_required([:platform, :external_id, :title])
  end
end
