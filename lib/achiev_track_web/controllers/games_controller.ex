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

  def achievements(conn, %{"platform" => platform, "external_id" => external_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Feed.list_game_achievements(user.id, platform, external_id) do
      {:ok, %{game: game, items: items}} ->
        render(conn, :achievements, game: game, items: items)

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Game not found"})
        |> halt()
    end
  end
end
