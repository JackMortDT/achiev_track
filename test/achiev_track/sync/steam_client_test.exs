defmodule AchievTrack.Sync.SteamClientTest do
  use ExUnit.Case, async: true

  alias AchievTrack.Sync.SteamClient

  setup do
    bypass = Bypass.open()
    %{bypass: bypass, base_url: "http://localhost:#{bypass.port}"}
  end

  describe "SteamClient.get_owned_games/3" do
    test "returns list of games on success", %{bypass: bypass, base_url: url} do
      Bypass.expect_once(bypass, "GET", "/IPlayerService/GetOwnedGames/v1/", fn conn ->
        body = Jason.encode!(%{
          response: %{
            game_count: 2,
            games: [
              %{appid: 440, name: "Team Fortress 2", img_icon_url: "abc123", playtime_forever: 100},
              %{appid: 570, name: "Dota 2", img_icon_url: "def456", playtime_forever: 0}
            ]
          }
        })
        Plug.Conn.resp(conn, 200, body)
      end)

      assert {:ok, games} = SteamClient.get_owned_games("fake_key", "76561198000000000", base_url: url)
      assert length(games) == 2
      assert hd(games).appid == 440
      assert hd(games).name == "Team Fortress 2"
    end

    test "returns error on non-200 status", %{bypass: bypass, base_url: url} do
      Bypass.expect_once(bypass, "GET", "/IPlayerService/GetOwnedGames/v1/", fn conn ->
        Plug.Conn.resp(conn, 401, Jason.encode!(%{}))
      end)

      assert {:error, {:http_error, 401}} =
        SteamClient.get_owned_games("bad_key", "76561198000000000", base_url: url)
    end

    test "returns error when response has no games key", %{bypass: bypass, base_url: url} do
      Bypass.expect_once(bypass, "GET", "/IPlayerService/GetOwnedGames/v1/", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{response: %{}}))
      end)

      assert {:ok, []} = SteamClient.get_owned_games("fake_key", "76561198000000000", base_url: url)
    end
  end

  describe "SteamClient.get_player_achievements/4" do
    test "returns list of achievements on success", %{bypass: bypass, base_url: url} do
      Bypass.expect_once(bypass, "GET", "/ISteamUserStats/GetPlayerAchievements/v1/", fn conn ->
        body = Jason.encode!(%{
          playerstats: %{
            steamID: "76561198000000000",
            gameName: "Team Fortress 2",
            success: true,
            achievements: [
              %{apiname: "ACH_PLAY", achieved: 1, unlocktime: 1_700_000_000,
                name: "Head of the Class", description: "Play every class."}
            ]
          }
        })
        Plug.Conn.resp(conn, 200, body)
      end)

      assert {:ok, achievements} =
        SteamClient.get_player_achievements("fake_key", "76561198000000000", 440, base_url: url)
      assert length(achievements) == 1
      assert hd(achievements).apiname == "ACH_PLAY"
      assert hd(achievements).achieved == 1
    end

    test "returns empty list when game has no stats (success: false)", %{bypass: bypass, base_url: url} do
      Bypass.expect_once(bypass, "GET", "/ISteamUserStats/GetPlayerAchievements/v1/", fn conn ->
        body = Jason.encode!(%{playerstats: %{success: false, error: "Requested app has no stats"}})
        Plug.Conn.resp(conn, 200, body)
      end)

      assert {:ok, []} =
        SteamClient.get_player_achievements("fake_key", "76561198000000000", 999, base_url: url)
    end
  end

  describe "get_game_schema/3" do
    test "returns map of apiname => image_url", %{bypass: bypass, base_url: url} do
      Bypass.expect_once(bypass, "GET", "/ISteamUserStats/GetSchemaForGame/v2/", fn conn ->
        body = Jason.encode!(%{game: %{availableGameStats: %{achievements: [
          %{name: "ACH_1", icon: "abc123", icongray: "gray123"},
          %{name: "ACH_2", icon: "def456", icongray: "gray456"}
        ]}}})
        Plug.Conn.resp(conn, 200, body)
      end)

      assert {:ok, schema} = AchievTrack.Sync.SteamClient.get_game_schema("api_key", 440, base_url: url)
      assert schema["ACH_1"] == "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/apps/440/abc123.jpg"
      assert schema["ACH_2"] == "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/apps/440/def456.jpg"
    end

    test "returns empty map when game has no achievements", %{bypass: bypass, base_url: url} do
      Bypass.expect_once(bypass, "GET", "/ISteamUserStats/GetSchemaForGame/v2/", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{game: %{}}))
      end)
      assert {:ok, %{}} = AchievTrack.Sync.SteamClient.get_game_schema("api_key", 440, base_url: url)
    end
  end
end
