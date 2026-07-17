defmodule AchievTrack.Accounts do
  import Ecto.Query
  alias AchievTrack.Repo
  alias AchievTrack.Accounts.User

  def register_user(attrs) do
    case %User{} |> User.changeset(attrs) |> Repo.insert() do
      {:ok, user} ->
        AchievTrack.Accounts.EmailVerification.generate_and_send(user)
        {:ok, user}
      {:error, changeset} ->
        {:error, changeset}
    end
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

  def upsert_steam_connection(user_id, steam_id) do
    %PlatformConnection{}
    |> PlatformConnection.changeset(%{
      "user_id" => user_id,
      "platform" => "steam",
      "external_id" => steam_id
    })
    |> Repo.insert(
      on_conflict: {:replace, [:external_id, :updated_at]},
      conflict_target: [:user_id, :platform],
      returning: true
    )
  end

  def find_or_create_by_steam(steam_id) do
    connection =
      Repo.one(
        from pc in PlatformConnection,
          where: pc.platform == "steam" and pc.external_id == ^steam_id,
          preload: [:user],
          limit: 1
      )

    case connection do
      %PlatformConnection{user: user} ->
        {:ok, user}

      nil ->
        api_key = Application.get_env(:achiev_track, :steam_api_key)
        {username, avatar_url} =
          case api_key && AchievTrack.Sync.SteamClient.get_player_summary(api_key, steam_id) do
            {:ok, %{username: name, avatar_url: avatar}} -> {sanitize_steam_username(name), avatar}
            _ -> {"steam_#{steam_id}", nil}
          end

        with {:ok, user} <- %User{} |> User.oauth_changeset(%{username: username, avatar_url: avatar_url}) |> Repo.insert(),
             {:ok, _} <- upsert_steam_connection(user.id, steam_id) do
          {:ok, user}
        end
    end
  end

  def find_or_create_by_google(%{google_id: nil}), do: {:error, :missing_google_id}

  def find_or_create_by_google(%{google_id: google_id, email: email, name: _name, avatar_url: avatar_url}) do
    case Repo.get_by(User, google_id: google_id) do
      %User{} = user ->
        {:ok, user}

      nil ->
        find_or_create_google_by_email(google_id, email, avatar_url)
    end
  end

  defp find_or_create_google_by_email(google_id, email, avatar_url) when not is_nil(email) do
    case Repo.one(from u in User, where: u.email == ^email) do
      %User{} = user ->
        user
        |> Ecto.Changeset.change(google_id: google_id)
        |> Repo.update()

      nil ->
        username = "google_#{google_id}"
        %User{}
        |> User.oauth_changeset(%{
          username: username,
          email: email,
          avatar_url: avatar_url,
          google_id: google_id
        })
        |> Repo.insert()
    end
  end

  defp find_or_create_google_by_email(google_id, _email, avatar_url) do
    username = "google_#{google_id}"
    %User{}
    |> User.oauth_changeset(%{username: username, avatar_url: avatar_url, google_id: google_id})
    |> Repo.insert()
  end

  def update_user(user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  def change_password(user, current_password, new_password) do
    if is_nil(user.password_hash) do
      {:error, :no_password_set}
    else
      if Bcrypt.verify_pass(current_password, user.password_hash) do
        user
        |> User.changeset(%{password: new_password})
        |> Repo.update()
      else
        {:error, :invalid_current_password}
      end
    end
  end

  def delete_user(user) do
    Repo.delete(user)
  end

  def get_user_with_connections(id) do
    Repo.one(from u in User, where: u.id == ^id, preload: :platform_connections)
  end

  alias AchievTrack.Accounts.Friendship

  def get_user_by_username(username) do
    Repo.one(from u in User, where: u.username == ^username)
  end

  def send_friend_request(requester_id, addressee_username) do
    case get_user_by_username(addressee_username) do
      nil ->
        {:error, :user_not_found}

      %User{id: id} when id == requester_id ->
        {:error, :cannot_friend_self}

      addressee ->
        result =
          %Friendship{requester_id: requester_id, addressee_id: addressee.id}
          |> Friendship.changeset(%{})
          |> Repo.insert()

        case result do
          {:ok, friendship} -> {:ok, friendship, addressee}
          {:error, _} = err -> err
        end
    end
  end

  def accept_friend_request(friendship_id, current_user_id) do
    case Repo.get(Friendship, friendship_id) do
      nil ->
        {:error, :not_found}

      %Friendship{addressee_id: ^current_user_id, status: "pending"} = f ->
        f |> Friendship.changeset(%{status: "accepted"}) |> Repo.update()

      _ ->
        {:error, :unauthorized}
    end
  end

  def remove_friend(friendship_id, current_user_id) do
    case Repo.get(Friendship, friendship_id) do
      nil ->
        {:error, :not_found}

      %Friendship{requester_id: rid, addressee_id: aid} = f
          when rid == current_user_id or aid == current_user_id ->
        Repo.delete(f)

      _ ->
        {:error, :unauthorized}
    end
  end

  def list_friends(user_id) do
    Repo.all(
      from f in Friendship,
        join: u in User,
          on:
            (f.requester_id == ^user_id and u.id == f.addressee_id) or
              (f.addressee_id == ^user_id and u.id == f.requester_id),
        where: f.status == "accepted",
        select: %{
          friendship_id: f.id,
          user_id: u.id,
          username: u.username,
          avatar_url: u.avatar_url,
          status: f.status
        }
    )
  end

  def list_pending_requests(user_id) do
    Repo.all(
      from f in Friendship,
        join: u in User, on: u.id == f.requester_id,
        where: f.addressee_id == ^user_id and f.status == "pending",
        select: %{
          friendship_id: f.id,
          user_id: u.id,
          username: u.username,
          avatar_url: u.avatar_url,
          status: f.status
        }
    )
  end

  defp sanitize_steam_username(name) do
    base =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9_]/, "_")
      |> String.slice(0, 28)
      |> String.trim("_")

    base = if String.length(base) < 2, do: "steam_user", else: base

    if Repo.one(from u in User, where: u.username == ^base) == nil do
      base
    else
      # Append incrementing suffix until unique
      Enum.find_value(1..99, base, fn n ->
        candidate = "#{base}_#{n}"
        if Repo.one(from u in User, where: u.username == ^candidate) == nil, do: candidate
      end)
    end
  end
end
