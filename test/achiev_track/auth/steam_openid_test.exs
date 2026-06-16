defmodule AchievTrack.Auth.SteamOpenIDTest do
  use ExUnit.Case, async: true

  alias AchievTrack.Auth.SteamOpenID

  describe "redirect_url/2" do
    test "returns a URL pointing to steamcommunity.com with required params" do
      url = SteamOpenID.redirect_url("http://localhost:4000", "abc123")
      uri = URI.parse(url)
      params = URI.decode_query(uri.query)
      assert uri.host == "steamcommunity.com"
      assert params["openid.mode"] == "checkid_setup"
      assert params["openid.ns"] == "http://specs.openid.net/auth/2.0"
      assert String.contains?(params["openid.return_to"], "abc123")
      assert params["openid.realm"] == "http://localhost:4000"
    end
  end

  describe "extract_steam_id/1" do
    test "extracts Steam ID from claimed_id URL" do
      params = %{
        "openid.claimed_id" => "https://steamcommunity.com/openid/id/76561198012345678",
        "openid.mode" => "id_res"
      }
      assert {:ok, "76561198012345678"} = SteamOpenID.extract_steam_id(params)
    end

    test "returns error for invalid claimed_id" do
      params = %{"openid.claimed_id" => "https://steamcommunity.com/openid/id/", "openid.mode" => "id_res"}
      assert {:error, :invalid_claimed_id} = SteamOpenID.extract_steam_id(params)
    end

    test "returns error when mode is cancel" do
      params = %{"openid.claimed_id" => "https://steamcommunity.com/openid/id/123", "openid.mode" => "cancel"}
      assert {:error, :cancelled} = SteamOpenID.extract_steam_id(params)
    end
  end

  describe "verify/2" do
    test "returns :ok when Steam confirms authentication" do
      bypass = Bypass.open()
      base_url = "http://localhost:#{bypass.port}"

      Bypass.expect_once(bypass, "POST", "/openid/login", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert String.contains?(body, "openid.mode=check_authentication")
        Plug.Conn.resp(conn, 200, "ns:http://specs.openid.net/auth/2.0\nis_valid:true\n")
      end)

      params = %{
        "openid.mode" => "id_res",
        "openid.claimed_id" => "https://steamcommunity.com/openid/id/76561198012345678",
        "openid.sig" => "fakesig",
        "openid.signed" => "mode,claimed_id"
      }
      assert :ok = SteamOpenID.verify(params, base_url: base_url)
    end

    test "returns error when Steam says is_valid:false" do
      bypass = Bypass.open()
      base_url = "http://localhost:#{bypass.port}"

      Bypass.expect_once(bypass, "POST", "/openid/login", fn conn ->
        Plug.Conn.resp(conn, 200, "ns:http://specs.openid.net/auth/2.0\nis_valid:false\n")
      end)

      params = %{"openid.mode" => "id_res", "openid.sig" => "bad", "openid.signed" => "mode"}
      assert {:error, :invalid_signature} = SteamOpenID.verify(params, base_url: base_url)
    end
  end
end
