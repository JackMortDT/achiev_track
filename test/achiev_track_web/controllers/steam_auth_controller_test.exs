defmodule AchievTrackWeb.SteamAuthControllerTest do
  use AchievTrackWeb.ConnCase

  alias AchievTrack.{Accounts, Auth.Guardian, Auth.SteamOpenIDState}

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "sso_user",
      email: "sso@example.com",
      password: "secret123"
    })
    {:ok, token, _} = Guardian.encode_and_sign(user)
    authed = build_conn() |> put_req_header("authorization", "Bearer #{token}")
    %{user: user, authed: authed}
  end

  describe "GET /api/auth/steam/initiate" do
    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/auth/steam/initiate")
      assert json_response(conn, 401)
    end

    test "returns steam_url with state token", %{authed: conn} do
      conn = get(conn, "/api/auth/steam/initiate")
      body = json_response(conn, 200)
      assert %{"steam_url" => url} = body
      assert String.contains?(url, "steamcommunity.com")
      assert String.contains?(url, "state")
    end
  end

  describe "GET /auth/steam/callback" do
    test "redirects to /configuracion?steam=error with invalid state", %{conn: conn} do
      params = %{
        "state" => "bad-state",
        "openid.mode" => "id_res",
        "openid.claimed_id" => "https://steamcommunity.com/openid/id/12345",
        "openid.sig" => "sig",
        "openid.signed" => "mode"
      }
      conn = get(conn, "/auth/steam/callback", params)
      assert redirected_to(conn) =~ "/configuracion?steam=error"
    end

    test "redirects to /configuracion?steam=error when mode is cancel", %{user: user, conn: conn} do
      SteamOpenIDState.put("valid-state", user.id)
      conn = get(conn, "/auth/steam/callback", %{
        "state" => "valid-state",
        "openid.mode" => "cancel"
      })
      assert redirected_to(conn) =~ "/configuracion?steam=error"
    end
  end
end
