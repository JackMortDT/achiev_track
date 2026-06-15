defmodule AchievTrackWeb.AuthController do
  use AchievTrackWeb, :controller

  alias AchievTrack.Accounts
  alias AchievTrack.Auth.Guardian

  def register(conn, params) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)
        conn
        |> put_status(:created)
        |> render(:auth, user: user, token: token)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:errors, changeset: changeset)
    end
  end

  def options(conn, _params) do
    send_resp(conn, 204, "")
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)
        render(conn, :auth, user: user, token: token)

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> render(:error, message: "Invalid email or password")
    end
  end
end
