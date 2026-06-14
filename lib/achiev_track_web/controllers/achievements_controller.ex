defmodule AchievTrackWeb.AchievementsController do
  use AchievTrackWeb, :controller

  alias AchievTrack.Feed
  alias AchievTrack.Auth.Guardian

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    opts =
      [platform: params["platform"], sort: params["sort"]]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    achievements = Feed.list_user_achievements(user.id, opts)
    render(conn, :index, achievements: achievements)
  end
end
