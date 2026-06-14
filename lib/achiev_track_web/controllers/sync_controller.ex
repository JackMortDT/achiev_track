defmodule AchievTrackWeb.SyncController do
  use AchievTrackWeb, :controller

  alias AchievTrack.Sync
  alias AchievTrack.Auth.Guardian

  def status(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    status = Sync.rate_limit_status(user.id)
    render(conn, :status, status: status)
  end

  def trigger(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Sync.trigger_sync(user.id) do
      {:ok, status} ->
        render(conn, :triggered, status: status)

      {:error, :rate_limited, status} ->
        conn
        |> put_status(429)
        |> render(:rate_limited, status: status)
    end
  end
end
