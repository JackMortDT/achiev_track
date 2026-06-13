defmodule AchievTrack.Accounts do
  import Ecto.Query
  alias AchievTrack.Repo
  alias AchievTrack.Accounts.User

  def register_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_user(email, password) do
    user = Repo.one(from u in User, where: u.email == ^email)
    cond do
      is_nil(user) ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
      Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}
      true ->
        {:error, :invalid_credentials}
    end
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

  alias AchievTrack.Accounts.PlatformConnection

  def connect_platform(user, platform, attrs) do
    %PlatformConnection{user_id: user.id}
    |> PlatformConnection.changeset(Map.merge(attrs, %{"platform" => platform}))
    |> Repo.insert()
  end

  def disconnect_platform(user, platform) do
    case Repo.get_by(PlatformConnection, user_id: user.id, platform: platform) do
      nil -> {:error, :not_found}
      connection -> Repo.delete(connection)
    end
  end

  def get_user_with_connections(id) do
    Repo.one(from u in User, where: u.id == ^id, preload: :platform_connections)
  end
end
