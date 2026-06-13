defmodule AchievTrackWeb.UserController do
  use AchievTrackWeb, :controller

  alias AchievTrack.Accounts
  alias AchievTrack.Auth.Guardian

  def show(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_with_connections = Accounts.get_user_with_connections(user.id)
    render(conn, :show, user: user_with_connections)
  end

  def connect_platform(conn, %{"platform" => platform} = params) do
    user = Guardian.Plug.current_resource(conn)
    attrs = Map.drop(params, ["platform"])

    case Accounts.connect_platform(user, platform, attrs) do
      {:ok, connection} ->
        conn
        |> put_status(:created)
        |> render(:platform_connection, connection: connection)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:errors, changeset: changeset)
    end
  end

  def disconnect_platform(conn, %{"platform" => platform}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.disconnect_platform(user, platform) do
      {:ok, _} ->
        json(conn, %{ok: true})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Platform not connected"})
    end
  end
end
