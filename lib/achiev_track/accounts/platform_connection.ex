defmodule AchievTrack.Accounts.PlatformConnection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_platforms ~w(steam retroachievements)

  schema "platform_connections" do
    field :platform, :string
    field :external_id, :string
    field :api_key, :string

    belongs_to :user, AchievTrack.Accounts.User

    timestamps()
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:user_id, :platform, :external_id, :api_key])
    |> validate_required([:user_id, :platform, :external_id])
    |> validate_inclusion(:platform, @valid_platforms,
        message: "must be one of: #{Enum.join(@valid_platforms, ", ")}")
    |> unique_constraint([:user_id, :platform], message: "platform already connected")
  end
end
