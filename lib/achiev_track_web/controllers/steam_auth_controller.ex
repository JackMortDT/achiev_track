defmodule AchievTrackWeb.SteamAuthController do
  use AchievTrackWeb, :controller

  alias AchievTrack.{Accounts, Sync}
  alias AchievTrack.Auth.{Guardian, SteamOpenID, SteamOpenIDState}

  defp frontend_url, do: Application.fetch_env!(:achiev_track, :frontend_url)
  defp backend_url, do: Application.fetch_env!(:achiev_track, :backend_url)
  defp cookie_opts, do: Application.get_env(:achiev_track, :cookie_opts)

  # Unauthenticated — starts Steam login/register flow
  def login(conn, _params) do
    state_token = Ecto.UUID.generate()
    SteamOpenIDState.put(state_token, :login)
    steam_url = SteamOpenID.redirect_url(backend_url(), state_token)
    json(conn, %{steam_url: steam_url})
  end

  # Authenticated — links Steam to an existing account
  def initiate(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    state_token = Ecto.UUID.generate()
    SteamOpenIDState.put(state_token, {:link, user.id})
    steam_url = SteamOpenID.redirect_url(backend_url(), state_token)
    json(conn, %{steam_url: steam_url})
  end

  def callback(conn, %{"state" => state_token} = params) do
    case SteamOpenIDState.pop(state_token) do
      {:ok, mode} ->
        with :ok <- SteamOpenID.verify(params),
             {:ok, steam_id} <- SteamOpenID.extract_steam_id(params) do
          handle_callback(conn, mode, steam_id)
        else
          _ -> error_redirect(conn, mode)
        end

      :error ->
        redirect(conn, external: "#{frontend_url()}/login?steam=error")
    end
  end

  def callback(conn, _params) do
    redirect(conn, external: "#{frontend_url()}/login?steam=error")
  end

  defp error_redirect(conn, :login),
    do: redirect(conn, external: "#{frontend_url()}/login?steam=error")

  defp error_redirect(conn, {:link, _}),
    do: redirect(conn, external: "#{frontend_url()}/configuracion?steam=error")

  defp handle_callback(conn, {:link, user_id}, steam_id) do
    case Accounts.upsert_steam_connection(user_id, steam_id) do
      {:ok, _} ->
        Sync.enqueue_steam_sync(user_id)
        redirect(conn, external: "#{frontend_url()}/configuracion?steam=connected")

      _ ->
        redirect(conn, external: "#{frontend_url()}/configuracion?steam=error")
    end
  end

  defp handle_callback(conn, :login, steam_id) do
    case Accounts.find_or_create_by_steam(steam_id) do
      {:ok, user} ->
        {:ok, token, _} = Guardian.encode_and_sign(user)
        conn
        |> put_resp_cookie("auth_token", token, cookie_opts())
        |> redirect(external: "#{frontend_url()}/perfil")

      _ ->
        redirect(conn, external: "#{frontend_url()}/login?steam=error")
    end
  end
end
