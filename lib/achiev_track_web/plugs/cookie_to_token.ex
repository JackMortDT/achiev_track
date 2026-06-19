defmodule AchievTrackWeb.Plugs.CookieToToken do
  @moduledoc """
  If no Authorization header is present, reads the `auth_token` cookie
  and injects it as a Bearer token so Guardian.Plug.VerifyHeader can pick it up.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      [] ->
        conn = fetch_cookies(conn)
        case conn.cookies["auth_token"] do
          nil -> conn
          token -> put_req_header(conn, "authorization", "Bearer #{token}")
        end

      _ ->
        conn
    end
  end
end
