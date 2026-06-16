defmodule AchievTrack.Sync.SteamWorkerTest do
  use AchievTrack.DataCase
  use Oban.Testing, repo: AchievTrack.Repo

  alias AchievTrack.Sync.SteamWorker
  alias AchievTrack.Accounts

  setup do
    bypass = Bypass.open()
    {:ok, user} = Accounts.register_user(%{
      username: "steam_user",
      email: "steam@example.com",
      password: "secret123"
    })
    {:ok, _conn} = Accounts.connect_platform(user, "steam", %{
      "external_id" => "76561198000000000"
    })
    %{bypass: bypass, user: user, base_url: "http://localhost:#{bypass.port}"}
  end

  test "syncs games and achievements, inserts catalog rows", %{bypass: bypass, user: user, base_url: url} do
    Bypass.expect(bypass, "GET", "/IPlayerService/GetOwnedGames/v1/", fn conn ->
      body = Jason.encode!(%{response: %{game_count: 1, games: [
        %{appid: 440, name: "Team Fortress 2", img_icon_url: "abc", playtime_forever: 100}
      ]}})
      Plug.Conn.resp(conn, 200, body)
    end)

    Bypass.expect(bypass, "GET", "/ISteamUserStats/GetPlayerAchievements/v1/", fn conn ->
      body = Jason.encode!(%{playerstats: %{
        success: true,
        achievements: [
          %{apiname: "ACH_1", achieved: 1, unlocktime: 1_700_000_000,
            name: "First Blood", description: "Kill someone."}
        ]
      }})
      Plug.Conn.resp(conn, 200, body)
    end)

    Bypass.expect(bypass, "GET", "/ISteamUserStats/GetSchemaForGame/v2/", fn conn ->
      Plug.Conn.resp(conn, 200, Jason.encode!(%{game: %{availableGameStats: %{achievements: []}}}))
    end)

    assert :ok = perform_job(SteamWorker, %{"user_id" => user.id, "steam_base_url" => url})

    # game was upserted
    import Ecto.Query
    game = AchievTrack.Repo.one(from g in AchievTrack.Catalog.Game, where: g.external_id == "440")
    assert game.title == "Team Fortress 2"
    assert game.platform == "steam"

    # achievement was upserted
    ach = AchievTrack.Repo.one(from a in AchievTrack.Catalog.Achievement, where: a.game_id == ^game.id)
    assert ach.external_id == "ACH_1"
    assert ach.title == "First Blood"

    # user_achievement was inserted
    ua = AchievTrack.Repo.one(from ua in AchievTrack.Catalog.UserAchievement, where: ua.user_id == ^user.id)
    assert ua.achievement_id == ach.id
  end

  test "returns :ok and skips user with no steam connection", %{} do
    {:ok, other_user} = Accounts.register_user(%{
      username: "no_steam",
      email: "nosteam@example.com",
      password: "secret123"
    })
    assert :ok = perform_job(SteamWorker, %{"user_id" => other_user.id})
  end

  test "fetches achievement icons from GetSchemaForGame", %{bypass: bypass, user: user, base_url: url} do
    Bypass.expect(bypass, "GET", "/IPlayerService/GetOwnedGames/v1/", fn conn ->
      body = Jason.encode!(%{response: %{game_count: 1, games: [
        %{appid: 730, name: "CS:GO", img_icon_url: "icon", playtime_forever: 50}
      ]}})
      Plug.Conn.resp(conn, 200, body)
    end)

    Bypass.expect(bypass, "GET", "/ISteamUserStats/GetPlayerAchievements/v1/", fn conn ->
      body = Jason.encode!(%{playerstats: %{
        success: true,
        achievements: [%{apiname: "WIN_1", achieved: 1, unlocktime: 1_700_000_000,
          name: "First Win", description: "Win a match."}]
      }})
      Plug.Conn.resp(conn, 200, body)
    end)

    Bypass.expect(bypass, "GET", "/ISteamUserStats/GetSchemaForGame/v2/", fn conn ->
      body = Jason.encode!(%{game: %{availableGameStats: %{achievements: [
        %{name: "WIN_1", icon: "abc123", icongray: "gray"}
      ]}}})
      Plug.Conn.resp(conn, 200, body)
    end)

    assert :ok = perform_job(SteamWorker, %{"user_id" => user.id, "steam_base_url" => url})

    import Ecto.Query
    game = AchievTrack.Repo.one(from g in AchievTrack.Catalog.Game, where: g.external_id == "730")
    ach = AchievTrack.Repo.one(from a in AchievTrack.Catalog.Achievement, where: a.game_id == ^game.id)
    assert ach.image_url =~ "abc123"
  end

  test "syncs using server api_key when connection has nil api_key", %{bypass: bypass} do
    {:ok, sso_user} = Accounts.register_user(%{
      username: "sso_worker_user",
      email: "ssoworker@example.com",
      password: "secret123"
    })
    {:ok, _} = Accounts.upsert_steam_connection(sso_user.id, "76561198000000099")

    Bypass.expect(bypass, "GET", "/IPlayerService/GetOwnedGames/v1/", fn conn ->
      Plug.Conn.resp(conn, 200, Jason.encode!(%{response: %{games: []}}))
    end)

    assert :ok = perform_job(SteamWorker, %{
      "user_id" => sso_user.id,
      "steam_base_url" => "http://localhost:#{bypass.port}"
    })
  end
end
