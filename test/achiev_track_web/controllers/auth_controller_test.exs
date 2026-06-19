defmodule AchievTrackWeb.AuthControllerTest do
  use AchievTrackWeb.ConnCase

  describe "POST /api/register" do
    test "returns 201 and sets cookie with valid params", %{conn: conn} do
      params = %{username: "new_user", email: "new@example.com", password: "secret123"}
      conn = post(conn, "/api/register", params)
      assert response(conn, 201)
      assert get_resp_header(conn, "set-cookie")
             |> Enum.any?(&String.starts_with?(&1, "auth_token="))
      body = json_response(conn, 201)
      assert Map.has_key?(body, "user")
      refute Map.has_key?(body, "token")
      user = body["user"]
      assert user["email"] == "new@example.com"
      assert user["username"] == "new_user"
      # id is a UUID string
      assert String.match?(user["id"], ~r/^[0-9a-f\-]{36}$/)
      refute Map.has_key?(user, "password_hash")
    end

    test "returns 422 with missing fields", %{conn: conn} do
      conn = post(conn, "/api/register", %{})
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 with duplicate email", %{conn: conn} do
      params = %{username: "user_a", email: "dup@example.com", password: "secret123"}
      post(conn, "/api/register", params)
      conn2 = post(conn, "/api/register", %{username: "user_b", email: "dup@example.com", password: "secret123"})
      assert %{"errors" => _} = json_response(conn2, 422)
    end
  end

  describe "POST /api/login" do
    setup do
      AchievTrack.Accounts.register_user(%{
        username: "existing_user",
        email: "existing@example.com",
        password: "secret123"
      })
      :ok
    end

    test "returns 200 and sets cookie with valid credentials", %{conn: conn} do
      conn = post(conn, "/api/login", %{email: "existing@example.com", password: "secret123"})
      assert response(conn, 200)
      assert get_resp_header(conn, "set-cookie")
             |> Enum.any?(&String.starts_with?(&1, "auth_token="))
      body = json_response(conn, 200)
      assert Map.has_key?(body, "user")
      refute Map.has_key?(body, "token")
    end

    test "returns 401 with wrong password", %{conn: conn} do
      conn = post(conn, "/api/login", %{email: "existing@example.com", password: "wrongpass"})
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "returns 401 with unknown email", %{conn: conn} do
      conn = post(conn, "/api/login", %{email: "nobody@example.com", password: "secret123"})
      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  describe "DELETE /api/logout" do
    test "clears the cookie", %{conn: conn} do
      conn = delete(conn, ~p"/api/logout")
      assert response(conn, 204)
      assert get_resp_header(conn, "set-cookie")
             |> Enum.any?(&String.contains?(&1, "auth_token=;"))
    end
  end

  describe "cookie round-trip authentication" do
    test "cookie from login grants access to a protected endpoint", %{conn: conn} do
      # Register and capture the cookie
      reg_conn = post(conn, ~p"/api/register", %{
        username: "roundtrip_user",
        email: "rt@example.com",
        password: "secret123"
      })
      assert response(reg_conn, 201)
      [set_cookie | _] = get_resp_header(reg_conn, "set-cookie")

      # Use the cookie on a protected endpoint
      authed_conn =
        conn
        |> put_req_header("cookie", set_cookie)
        |> get(~p"/api/me")

      assert response(authed_conn, 200)
    end
  end
end
