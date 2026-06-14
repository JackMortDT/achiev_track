defmodule AchievTrackWeb.EventsController do
  use AchievTrackWeb, :controller

  alias AchievTrack.{Auth, Notifications}

  def subscribe(conn, _params) do
    user = Auth.Guardian.Plug.current_resource(conn)
    Notifications.subscribe(user.id)

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    case chunk(conn, ": keepalive\n\n") do
      {:ok, conn} -> event_loop(conn)
      {:error, _} -> conn
    end
  end

  defp event_loop(conn) do
    receive do
      {:new_achievements, count} ->
        data = Jason.encode!(%{type: "new_achievements", count: count})
        case chunk(conn, "data: #{data}\n\n") do
          {:ok, conn} -> event_loop(conn)
          {:error, _} -> conn
        end
    after
      30_000 ->
        case chunk(conn, ": heartbeat\n\n") do
          {:ok, conn} -> event_loop(conn)
          {:error, _} -> conn
        end
    end
  end
end
