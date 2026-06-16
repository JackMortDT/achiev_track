defmodule AchievTrackWeb.SteamAuthController do
  use AchievTrackWeb, :controller

  alias AchievTrack.{Accounts, Sync}
  alias AchievTrack.Auth.{Guardian, SteamOpenID, SteamOpenIDState}

  @frontend_url Application.compile_env(:achiev_track, :frontend_url, "http://localhost:3000")
  @backend_url Application.compile_env(:achiev_track, :backend_url, "http://localhost:4000")

  def initiate(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    state_token = Ecto.UUID.generate()
    SteamOpenIDState.put(state_token, user.id)
    steam_url = SteamOpenID.redirect_url(@backend_url, state_token)
    json(conn, %{steam_url: steam_url})
  end

  def callback(conn, %{"state" => state_token} = params) do
    with {:ok, user_id} <- SteamOpenIDState.pop(state_token),
         :ok <- SteamOpenID.verify(params),
         {:ok, steam_id} <- SteamOpenID.extract_steam_id(params),
         {:ok, _conn} <- Accounts.upsert_steam_connection(user_id, steam_id) do
      Sync.enqueue_steam_sync(user_id)
      redirect(conn, external: "#{@frontend_url}/configuracion?steam=connected")
    else
      _ ->
        redirect(conn, external: "#{@frontend_url}/configuracion?steam=error")
    end
  end

  def callback(conn, _params) do
    redirect(conn, external: "#{@frontend_url}/configuracion?steam=error")
  end
end
