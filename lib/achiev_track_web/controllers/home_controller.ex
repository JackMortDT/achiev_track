defmodule AchievTrackWeb.HomeController do
  use AchievTrackWeb, :controller

  alias AchievTrack.{Feed, Auth.Guardian}

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    data = Feed.home_data(user.id)
    render(conn, :index, data: data)
  end
end
