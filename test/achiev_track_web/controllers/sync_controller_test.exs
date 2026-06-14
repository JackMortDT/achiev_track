defmodule AchievTrackWeb.SyncControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.{Accounts, Sync}
  alias AchievTrack.Auth.Guardian

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "sync_ctrl_user",
      email: "syncctr@example.com",
      password: "secret123"
    })
    {:ok, token, _} = Guardian.encode_and_sign(user)
    authed_conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")
    %{user: user, authed_conn: authed_conn}
  end

  describe "GET /api/sync/status" do
    test "returns rate limit status when authenticated", %{authed_conn: conn} do
      conn = get(conn, "/api/sync/status")
      assert %{
        "allowed" => true,
        "syncs_used" => 0,
        "syncs_remaining" => 3,
        "next_available_at" => nil
      } = json_response(conn, 200)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/sync/status")
      assert %{"error" => "Unauthorized"} = json_response(conn, 401)
    end
  end

  describe "POST /api/sync" do
    test "returns 200 and enqueues jobs when allowed", %{authed_conn: conn, user: user} do
      Accounts.connect_platform(user, "steam", %{"external_id" => "76561198000000000"})
      conn = post(conn, "/api/sync")
      assert %{"ok" => true, "syncs_remaining" => remaining} = json_response(conn, 200)
      assert remaining == 2
    end

    test "returns 429 when rate limit reached", %{authed_conn: conn, user: user} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Sync.record_sync(user.id, now)
      Sync.record_sync(user.id, now)
      Sync.record_sync(user.id, now)
      conn = post(conn, "/api/sync")
      assert %{"error" => "rate_limited", "next_available_at" => _} = json_response(conn, 429)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = post(conn, "/api/sync")
      assert %{"error" => "Unauthorized"} = json_response(conn, 401)
    end
  end
end
