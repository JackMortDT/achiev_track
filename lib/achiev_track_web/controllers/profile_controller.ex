defmodule AchievTrackWeb.ProfileController do
  use AchievTrackWeb, :controller

  alias AchievTrack.{Accounts, Feed, Sync}
  alias AchievTrack.Auth.Guardian

  def show(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_with_platforms = Accounts.get_user_with_connections(user.id)
    stats = Feed.get_user_stats(user.id)
    sync_status = Sync.rate_limit_status(user.id)
    render(conn, :show, user: user_with_platforms, stats: stats, sync_status: sync_status)
  end
end
