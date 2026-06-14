defmodule AchievTrackWeb.FriendsController do
  use AchievTrackWeb, :controller

  alias AchievTrack.{Accounts, Feed}
  alias AchievTrack.Auth.Guardian

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    render(conn, :index, friends: Accounts.list_friends(user.id))
  end

  def pending(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    render(conn, :index, friends: Accounts.list_pending_requests(user.id))
  end

  def create(conn, %{"username" => username}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.send_friend_request(user.id, username) do
      {:ok, friendship, addressee} ->
        conn
        |> put_status(201)
        |> json(%{
          friendship_id: friendship.id,
          user_id: addressee.id,
          username: addressee.username,
          status: "pending"
        })

      {:error, :user_not_found} ->
        conn |> put_status(404) |> json(%{error: "User not found"})

      {:error, :cannot_friend_self} ->
        conn |> put_status(422) |> json(%{error: "Cannot friend yourself"})

      {:error, _changeset} ->
        conn |> put_status(422) |> json(%{error: "Already friends or request pending"})
    end
  end

  def accept(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.accept_friend_request(id, user.id) do
      {:ok, _} -> json(conn, %{ok: true})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Not found"})
      {:error, :unauthorized} -> conn |> put_status(403) |> json(%{error: "Forbidden"})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.remove_friend(id, user.id) do
      {:ok, _} -> send_resp(conn, 204, "")
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Not found"})
      {:error, :unauthorized} -> conn |> put_status(403) |> json(%{error: "Forbidden"})
    end
  end

  def leaderboard(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    entries = Feed.friends_leaderboard(user.id)
    render(conn, :leaderboard, entries: entries, current_user_id: user.id)
  end

  def compare(conn, %{"user_id" => friend_id}) do
    user = Guardian.Plug.current_resource(conn)

    # Verify friendship exists before returning data
    friends = Accounts.list_friends(user.id)
    if Enum.any?(friends, &(to_string(&1.user_id) == friend_id)) do
      data = Feed.compare_with_friend(user.id, friend_id)
      render(conn, :compare, data: data)
    else
      conn |> put_status(403) |> json(%{error: "Not friends"})
    end
  end
end
