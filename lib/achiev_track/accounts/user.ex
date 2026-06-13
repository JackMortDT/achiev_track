defmodule AchievTrack.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string
    field :avatar_url, :string
    field :password, :string, virtual: true

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password, :avatar_url])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 2, max: 30)
    |> validate_length(:password, min: 6)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> hash_password()
  end

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    changeset
    |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
    |> delete_change(:password)
  end

  defp hash_password(changeset), do: changeset
end
