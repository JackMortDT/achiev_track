defmodule AchievTrack.Accounts.Friendship do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "friendships" do
    field :status, :string, default: "pending"
    belongs_to :requester, AchievTrack.Accounts.User
    belongs_to :addressee, AchievTrack.Accounts.User

    timestamps()
  end

  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, ["pending", "accepted"])
    |> unique_constraint([:requester_id, :addressee_id],
        name: :friendships_requester_id_addressee_id_index)
  end
end
