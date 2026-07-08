defmodule AchievTrackWeb.Plugs.DynamicCORS do
  @moduledoc """
  Wraps CORSPlug but reads the allowed origin from Application config at call time,
  so that runtime.exs values (set after compile) are respected.
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    frontend_url = Application.get_env(:achiev_track, :frontend_url, "http://localhost:3000")

    cors_opts =
      CORSPlug.init(
        origin: [frontend_url],
        credentials: true,
        methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        headers: ["Authorization", "Content-Type", "Accept"]
      )

    CORSPlug.call(conn, cors_opts)
  end
end
