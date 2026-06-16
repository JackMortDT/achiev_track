defmodule AchievTrackWeb.UserControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.Accounts
  alias AchievTrack.Auth.Guardian

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "test_user",
      email: "test@example.com",
      password: "secret123"
    })
    {:ok, token, _} = Guardian.encode_and_sign(user)
    authed_conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")
    %{user: user, authed_conn: authed_conn, authed: authed_conn}
  end

  describe "GET /api/me" do
    test "returns user profile with UUID id when authenticated", %{authed_conn: conn, user: user} do
      conn = get(conn, "/api/me")
      assert %{"id" => id, "username" => username, "platform_connections" => connections} =
        json_response(conn, 200)
      assert id == user.id
      assert String.match?(id, ~r/^[0-9a-f\-]{36}$/)
      assert username == "test_user"
      assert connections == []
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/me")
      assert %{"error" => "Unauthorized"} = json_response(conn, 401)
    end
  end

  describe "POST /api/me/platforms" do
    test "connects steam platform", %{authed_conn: conn} do
      params = %{platform: "steam", external_id: "76561198000000000"}
      conn = post(conn, "/api/me/platforms", params)
      assert %{"platform" => "steam", "external_id" => "76561198000000000"} =
        json_response(conn, 201)
    end

    test "connects retroachievements platform", %{authed_conn: conn} do
      params = %{platform: "retroachievements", external_id: "player_one", api_key: "abc123"}
      conn = post(conn, "/api/me/platforms", params)
      assert %{"platform" => "retroachievements"} = json_response(conn, 201)
    end

    test "returns 422 for invalid platform", %{authed_conn: conn} do
      params = %{platform: "psn", external_id: "id123"}
      conn = post(conn, "/api/me/platforms", params)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 if platform already connected", %{authed_conn: conn} do
      params = %{platform: "steam", external_id: "76561198000000000"}
      post(conn, "/api/me/platforms", params)
      conn2 = post(conn, "/api/me/platforms", params)
      assert %{"errors" => _} = json_response(conn2, 422)
    end
  end

  describe "DELETE /api/me/platforms/:platform" do
    test "disconnects a connected platform", %{authed_conn: conn, user: user} do
      Accounts.connect_platform(user, "steam", %{"external_id" => "76561198000000000"})
      conn = delete(conn, "/api/me/platforms/steam")
      assert json_response(conn, 200) == %{"ok" => true}
    end

    test "returns 404 if platform not connected", %{authed_conn: conn} do
      conn = delete(conn, "/api/me/platforms/steam")
      assert %{"error" => _} = json_response(conn, 404)
    end
  end

  describe "PATCH /api/me" do
    test "updates username", %{authed: authed} do
      conn = patch(authed, "/api/me", %{username: "newname"})
      assert %{"username" => "newname"} = json_response(conn, 200)
    end

    test "updates avatar_url", %{authed: authed} do
      conn = patch(authed, "/api/me", %{avatar_url: "🎮"})
      assert %{"avatar_url" => "🎮"} = json_response(conn, 200)
    end

    test "returns 422 with invalid username", %{authed: authed} do
      conn = patch(authed, "/api/me", %{username: "x"})
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = patch(conn, "/api/me", %{username: "foo"})
      assert json_response(conn, 401)
    end
  end

  describe "PATCH /api/me/password" do
    test "changes password with correct current password", %{authed: authed} do
      conn = patch(authed, "/api/me/password", %{
        current_password: "secret123",
        new_password: "newpass456"
      })
      assert %{"ok" => true} = json_response(conn, 200)
    end

    test "returns 422 with wrong current password", %{authed: authed} do
      conn = patch(authed, "/api/me/password", %{
        current_password: "wrongpass",
        new_password: "newpass456"
      })
      assert %{"error" => _} = json_response(conn, 422)
    end
  end

  describe "DELETE /api/me" do
    test "deletes the user account", %{authed: authed, user: user} do
      conn = delete(authed, "/api/me")
      assert response(conn, 204)
      assert is_nil(AchievTrack.Accounts.get_user(user.id))
    end

    test "returns 401 without token", %{conn: conn} do
      conn = delete(conn, "/api/me")
      assert json_response(conn, 401)
    end
  end
end
