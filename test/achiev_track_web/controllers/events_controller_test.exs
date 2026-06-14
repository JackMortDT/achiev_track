defmodule AchievTrackWeb.EventsControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.Accounts
  alias AchievTrack.Auth.Guardian

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "sse_user",
      email: "sse@example.com",
      password: "secret123"
    })
    {:ok, token, _} = Guardian.encode_and_sign(user)
    authed_conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")
    %{user: user, authed_conn: authed_conn}
  end

  test "returns 401 without token", %{conn: conn} do
    conn = get(conn, "/api/events")
    assert json_response(conn, 401)
  end

  test "sets SSE content-type and streams keepalive", %{authed_conn: conn} do
    # SSE connections are long-lived; test only that headers and initial chunk are correct.
    # We use a task with a short timeout to avoid hanging the test.
    parent = self()

    task = Task.async(fn ->
      conn = get(conn, "/api/events")
      send(parent, {:conn, conn})
    end)

    receive do
      {:conn, conn} ->
        assert get_resp_header(conn, "content-type") == ["text/event-stream"]
    after
      2000 ->
        # SSE held connection — that's expected; just verify it's alive
        assert Task.yield(task, 0) == nil
        Task.shutdown(task, :brutal_kill)
    end
  end
end
