defmodule AchievTrackWeb.GamesController do
  use AchievTrackWeb, :controller

  alias AchievTrack.Feed
  alias AchievTrack.Auth.Guardian

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    status = params["status"] || "all"
    games = Feed.list_user_games(user.id, status)
    render(conn, :index, games: games)
  end
end
