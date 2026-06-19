defmodule AchievTrackWeb.AuthController do
  use AchievTrackWeb, :controller

  alias AchievTrack.Accounts
  alias AchievTrack.Auth.Guardian

  @cookie_name "auth_token"

  defp cookie_opts, do: Application.get_env(:achiev_track, :cookie_opts)

  def register(conn, params) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)
        conn
        |> put_resp_cookie(@cookie_name, token, cookie_opts())
        |> put_status(:created)
        |> render(:auth, user: user)

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
        conn
        |> put_resp_cookie(@cookie_name, token, cookie_opts())
        |> render(:auth, user: user)

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> render(:error, message: "Invalid email or password")
    end
  end

  def logout(conn, _params) do
    opts = cookie_opts() |> Keyword.take([:domain, :path])
    conn
    |> delete_resp_cookie(@cookie_name, opts)
    |> send_resp(204, "")
  end
end
