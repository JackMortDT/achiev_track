defmodule AchievTrackWeb.GamesController do
  use AchievTrackWeb, :controller

  alias AchievTrack.Feed
  alias AchievTrack.Auth.Guardian

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    opts =
      [
        status: params["status"] || "all",
        platform: params["platform"]
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    games = Feed.list_user_games(user.id, opts)
    render(conn, :index, games: games)
  end

  def platforms(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    platforms = Feed.list_user_platforms(user.id)
    render(conn, :platforms, platforms: platforms)
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
