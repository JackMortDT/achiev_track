defmodule AchievTrack.Sync.RetroWorkerTest do
  use AchievTrack.DataCase
  use Oban.Testing, repo: AchievTrack.Repo

  alias AchievTrack.Sync.RetroWorker
  alias AchievTrack.Accounts

  setup do
    bypass = Bypass.open()
    {:ok, user} = Accounts.register_user(%{
      username: "ra_user",
      email: "ra@example.com",
      password: "secret123"
    })
    {:ok, _conn} = Accounts.connect_platform(user, "retroachievements", %{
      "external_id" => "ra_player",
      "api_key" => "ra_api_key_123"
    })
    %{bypass: bypass, user: user, base_url: "http://localhost:#{bypass.port}"}
  end

  test "syncs RA games and achievements", %{bypass: bypass, user: user, base_url: url} do
    Bypass.expect(bypass, "GET", "/API/API_GetUserCompletionProgress.php", fn conn ->
      body = Jason.encode!(%{Results: [
        %{GameID: 1234, Title: "Super Mario Bros.", ImageIcon: "/Images/000001.png",
          NumAwarded: 1, MaxPossible: 2}
      ]})
      Plug.Conn.resp(conn, 200, body)
    end)

    Bypass.expect(bypass, "GET", "/API/API_GetGameInfoAndUserProgress.php", fn conn ->
      body = Jason.encode!(%{
        ID: 1234, Title: "Super Mario Bros.", ImageIcon: "/Images/000001.png",
        NumAchievements: 2,
        Achievements: %{
          "1" => %{ID: 1, Title: "First Step", Description: "Complete 1-1.",
                   Points: 5, BadgeName: "00001", DateEarned: "2023-06-01 10:00:00"},
          "2" => %{ID: 2, Title: "No Deaths", Description: "No deaths.", Points: 25,
                   BadgeName: "00002", DateEarned: nil}
        }
      })
      Plug.Conn.resp(conn, 200, body)
    end)

    assert :ok = perform_job(RetroWorker, %{"user_id" => user.id, "ra_base_url" => url})

    import Ecto.Query
    game = AchievTrack.Repo.one(from g in AchievTrack.Catalog.Game, where: g.external_id == "1234")
    assert game.platform == "retroachievements"
    assert game.title == "Super Mario Bros."

    achievements = AchievTrack.Repo.all(from a in AchievTrack.Catalog.Achievement, where: a.game_id == ^game.id)
    assert length(achievements) == 2

    user_achievements = AchievTrack.Repo.all(from ua in AchievTrack.Catalog.UserAchievement, where: ua.user_id == ^user.id)
    # Only DateEarned non-nil → 1 new unlock
    assert length(user_achievements) == 1
  end

  test "returns :ok and skips user with no RA connection", %{} do
    {:ok, other} = Accounts.register_user(%{
      username: "no_ra", email: "nora@example.com", password: "secret123"
    })
    assert :ok = perform_job(RetroWorker, %{"user_id" => other.id})
  end

  describe "console name normalization" do
    test "stores normalized console name as platform for GBA games", %{user: user, bypass: bypass} do
      Bypass.expect(bypass, "GET", "/API/API_GetUserCompletionProgress.php", fn conn ->
        body = Jason.encode!(%{"Results" => [
          %{"GameID" => 999, "Title" => "Test GBA Game", "ImageIcon" => "/icon.png",
            "NumAwarded" => 1, "MaxPossible" => 2}
        ]})
        Plug.Conn.send_resp(conn, 200, body)
      end)

      Bypass.expect(bypass, "GET", "/API/API_GetGameInfoAndUserProgress.php", fn conn ->
        body = Jason.encode!(%{
          "ID" => 999, "Title" => "Test GBA Game",
          "ConsoleName" => "Game Boy Advance",
          "ImageIcon" => "/icon.png", "NumAchievements" => 2,
          "Achievements" => %{
            "1" => %{"ID" => 1, "Title" => "First", "Description" => "Desc",
                     "Points" => 5, "BadgeName" => "badge1", "DateEarned" => nil}
          }
        })
        Plug.Conn.send_resp(conn, 200, body)
      end)

      base_url = "http://localhost:#{bypass.port}"
      AchievTrack.Sync.RetroWorker.perform(%Oban.Job{
        args: %{"user_id" => user.id, "ra_base_url" => base_url}
      })

      import Ecto.Query
      game = AchievTrack.Repo.one!(
        from g in AchievTrack.Catalog.Game, where: g.external_id == "999"
      )
      assert game.platform == "gba"
    end

    test "stores 'psx' for PlayStation games" do
      assert AchievTrack.Sync.RetroWorker.normalize_console("PlayStation") == "psx"
    end

    test "stores 'snes' for Super Nintendo games" do
      assert AchievTrack.Sync.RetroWorker.normalize_console("Super Nintendo") == "snes"
    end

    test "falls back to slugified name for unknown consoles" do
      assert AchievTrack.Sync.RetroWorker.normalize_console("Unknown Console") == "unknownconsole"
    end
  end
end
