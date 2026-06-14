defmodule AchievTrack.Sync.RetroClientTest do
  use ExUnit.Case, async: true

  alias AchievTrack.Sync.RetroClient

  setup do
    bypass = Bypass.open()
    %{bypass: bypass, base_url: "http://localhost:#{bypass.port}"}
  end

  describe "RetroClient.get_user_games/3" do
    test "returns list of games on success", %{bypass: bypass, base_url: url} do
      Bypass.expect_once(bypass, "GET", "/API/API_GetUserCompletionProgress.php", fn conn ->
        body = Jason.encode!(%{
          Results: [
            %{GameID: 1234, Title: "Super Mario Bros.", ImageIcon: "/Images/000001.png",
              NumAwarded: 5, MaxPossible: 10},
            %{GameID: 5678, Title: "Metroid", ImageIcon: "/Images/000002.png",
              NumAwarded: 0, MaxPossible: 8}
          ]
        })
        Plug.Conn.resp(conn, 200, body)
      end)

      assert {:ok, games} = RetroClient.get_user_games("player_one", "api_key_123", base_url: url)
      assert length(games) == 2
      assert hd(games).game_id == 1234
      assert hd(games).title == "Super Mario Bros."
      assert hd(games).num_awarded == 5
      assert hd(games).max_possible == 10
    end

    test "returns error on non-200", %{bypass: bypass, base_url: url} do
      Bypass.expect_once(bypass, "GET", "/API/API_GetUserCompletionProgress.php", fn conn ->
        Plug.Conn.resp(conn, 401, "Unauthorized")
      end)

      assert {:error, {:http_error, 401}} =
        RetroClient.get_user_games("player_one", "bad_key", base_url: url)
    end
  end

  describe "RetroClient.get_game_progress/4" do
    test "returns game details with achievements", %{bypass: bypass, base_url: url} do
      Bypass.expect_once(bypass, "GET", "/API/API_GetGameInfoAndUserProgress.php", fn conn ->
        body = Jason.encode!(%{
          ID: 1234,
          Title: "Super Mario Bros.",
          ImageIcon: "/Images/000001.png",
          NumAchievements: 2,
          Achievements: %{
            "1" => %{ID: 1, Title: "First Step", Description: "Complete 1-1.",
                     Points: 5, BadgeName: "00001", DateEarned: "2023-06-01 10:00:00"},
            "2" => %{ID: 2, Title: "No Deaths", Description: "Complete without dying.",
                     Points: 25, BadgeName: "00002", DateEarned: nil}
          }
        })
        Plug.Conn.resp(conn, 200, body)
      end)

      assert {:ok, game} =
        RetroClient.get_game_progress("player_one", "api_key_123", 1234, base_url: url)
      assert game.id == 1234
      assert game.title == "Super Mario Bros."
      assert length(game.achievements) == 2
      earned = Enum.find(game.achievements, &(&1.id == 1))
      assert earned.date_earned == "2023-06-01 10:00:00"
      assert earned.points == 5
    end
  end
end
