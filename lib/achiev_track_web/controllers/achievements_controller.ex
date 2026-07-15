defmodule AchievTrackWeb.AchievementsController do
  use AchievTrackWeb, :controller

  alias AchievTrack.Feed
  alias AchievTrack.Auth.Guardian

  def locked(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    items = Feed.list_locked_achievements_with_rarity(user.id, params["platform"])
    render(conn, :locked, items: items)
  end

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    page = String.to_integer(params["page"] || "1")
    per_page = String.to_integer(params["per_page"] || "100")

    opts =
      [platform: params["platform"], sort: params["sort"], page: page, per_page: per_page]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    result = Feed.list_user_achievements(user.id, opts)
    render(conn, :index, result: result)
  end
end
