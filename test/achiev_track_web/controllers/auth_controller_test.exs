defmodule AchievTrackWeb.AuthControllerTest do
  use AchievTrackWeb.ConnCase

  describe "POST /api/register" do
    test "returns 201 and token with valid params", %{conn: conn} do
      params = %{username: "new_user", email: "new@example.com", password: "secret123"}
      conn = post(conn, "/api/register", params)
      assert %{"token" => token, "user" => user} = json_response(conn, 201)
      assert is_binary(token)
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

    test "returns 200 and token with valid credentials", %{conn: conn} do
      conn = post(conn, "/api/login", %{email: "existing@example.com", password: "secret123"})
      assert %{"token" => token, "user" => _} = json_response(conn, 200)
      assert is_binary(token)
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
end
