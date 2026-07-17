defmodule AchievTrackWeb.GoogleAuthController do
  use AchievTrackWeb, :controller

  alias AchievTrack.Accounts
  alias AchievTrack.Auth.{Guardian, GoogleOAuth, GoogleAuthState}

  defp frontend_url, do: Application.fetch_env!(:achiev_track, :frontend_url)
  defp cookie_opts, do: Application.get_env(:achiev_track, :cookie_opts)

  def login(conn, _params) do
    state_token = Ecto.UUID.generate()
    GoogleAuthState.put(state_token)
    google_url = GoogleOAuth.redirect_url(state_token)
    json(conn, %{google_url: google_url})
  end

  def callback(conn, %{"state" => state_token, "code" => code}) do
    with :ok <- GoogleAuthState.pop(state_token),
         {:ok, %{"access_token" => access_token}} <- GoogleOAuth.exchange_code(code),
         {:ok, user_info} <- GoogleOAuth.get_user_info(access_token),
         {:ok, user} <- Accounts.find_or_create_by_google(user_info) do
      {:ok, token, _} = Guardian.encode_and_sign(user)

      conn
      |> put_resp_cookie("auth_token", token, cookie_opts())
      |> redirect(external: "#{frontend_url()}/perfil")
    else
      _ ->
        redirect(conn, external: "#{frontend_url()}/login?google=error")
    end
  end

  def callback(conn, _params) do
    redirect(conn, external: "#{frontend_url()}/login?google=error")
  end
end
