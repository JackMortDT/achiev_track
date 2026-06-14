defmodule AchievTrackWeb.FriendsControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.Accounts
  alias AchievTrack.Auth.Guardian

  defp make_user(username) do
    {:ok, u} = Accounts.register_user(%{username: username, email: "#{username}@example.com", password: "secret123"})
    u
  end

  defp authed_conn(user) do
    {:ok, token, _} = Guardian.encode_and_sign(user)
    build_conn() |> put_req_header("authorization", "Bearer #{token}")
  end

  setup do
    user = make_user("fr_user")
    %{user: user, conn: authed_conn(user)}
  end

  test "GET /api/friends returns 401 without token", %{} do
    conn = get(build_conn(), "/api/friends")
    assert json_response(conn, 401)
  end

  test "GET /api/friends returns empty list for new user", %{conn: conn} do
    conn = get(conn, "/api/friends")
    assert [] = json_response(conn, 200)
  end

  test "POST /api/friends sends a friend request", %{conn: conn} do
    other = make_user("target_user")
    conn = post(conn, "/api/friends", %{username: other.username})
    body = json_response(conn, 201)
    assert body["username"] == "target_user"
    assert body["status"] == "pending"
  end

  test "POST /api/friends returns 404 for unknown user", %{conn: conn} do
    conn = post(conn, "/api/friends", %{username: "nobody"})
    assert %{"error" => "User not found"} = json_response(conn, 404)
  end

  test "POST /api/friends returns 422 when friending self", %{conn: conn, user: user} do
    conn = post(conn, "/api/friends", %{username: user.username})
    assert json_response(conn, 422)
  end

  test "PUT /api/friends/:id/accept accepts a pending request", %{conn: conn, user: user} do
    requester = make_user("req_user")
    {:ok, friendship, _} = Accounts.send_friend_request(requester.id, user.username)

    conn = put(conn, "/api/friends/#{friendship.id}/accept")
    assert %{"ok" => true} = json_response(conn, 200)
  end

  test "PUT /api/friends/:id/accept returns 403 when current user is not the addressee", %{conn: _conn, user: user} do
    other = make_user("not_addressee")
    third = make_user("third_party")
    {:ok, friendship, _} = Accounts.send_friend_request(user.id, other.username)

    # third_party tries to accept a friendship they are not part of
    third_conn = authed_conn(third)
    resp = put(third_conn, "/api/friends/#{friendship.id}/accept")
    assert json_response(resp, 403)
  end

  test "DELETE /api/friends/:id removes a friend", %{conn: conn, user: user} do
    other = make_user("del_friend")
    {:ok, friendship, _} = Accounts.send_friend_request(user.id, other.username)
    Accounts.accept_friend_request(friendship.id, other.id)

    conn = delete(conn, "/api/friends/#{friendship.id}")
    assert response(conn, 204)
  end

  test "GET /api/friends/leaderboard returns ranked list including self", %{conn: conn, user: user} do
    conn = get(conn, "/api/friends/leaderboard")
    entries = json_response(conn, 200)
    assert length(entries) >= 1
    first = hd(entries)
    assert first["rank"] == 1
    assert Map.has_key?(first, "total_points")
    me = Enum.find(entries, &(&1["user_id"] == user.id))
    assert me["is_me"] == true
  end

  test "GET /api/friends/pending returns pending requests", %{conn: conn, user: user} do
    requester = make_user("pending_req")
    Accounts.send_friend_request(requester.id, user.username)

    conn = get(conn, "/api/friends/pending")
    [req] = json_response(conn, 200)
    assert req["username"] == "pending_req"
    assert req["status"] == "pending"
  end

  test "GET /api/friends/:user_id/compare returns comparison data", %{conn: conn, user: user} do
    friend = make_user("comp_friend")
    {:ok, f, _} = Accounts.send_friend_request(user.id, friend.username)
    Accounts.accept_friend_request(f.id, friend.id)

    conn = get(conn, "/api/friends/#{friend.id}/compare")
    body = json_response(conn, 200)
    assert Map.has_key?(body, "user")
    assert Map.has_key?(body, "friend")
    assert body["friend"]["username"] == "comp_friend"
    assert Map.has_key?(body, "shared_games")
  end

  test "GET /api/friends/:user_id/compare returns 403 when not friends", %{conn: conn} do
    stranger = make_user("stranger_user")
    conn = get(conn, "/api/friends/#{stranger.id}/compare")
    assert %{"error" => "Not friends"} = json_response(conn, 403)
  end
end
