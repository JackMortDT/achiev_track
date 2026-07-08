defmodule AchievTrack.Sync.RetroWorker do
  use Oban.Worker, queue: :sync

  alias AchievTrack.{Catalog, Notifications, Repo}
  alias AchievTrack.Sync.RetroClient

  @console_map %{
    "game boy advance" => "gba",
    "game boy color" => "gbc",
    "game boy" => "gb",
    "super nintendo" => "snes",
    "nintendo 64" => "n64",
    "nes/famicom" => "nes",
    "playstation" => "psx",
    "playstation 2" => "ps2",
    "mega drive" => "genesis",
    "genesis" => "genesis",
    "genesis/mega drive" => "genesis",
    "master system" => "mastersystem",
    "game gear" => "gamegear",
    "arcade" => "arcade",
    "atari 2600" => "atari2600",
    "atari 7800" => "atari7800",
    "neo geo" => "neogeo",
    "pc engine" => "pcengine",
    "turbografx-16" => "pcengine",
    "saturn" => "saturn",
    "dreamcast" => "dreamcast",
    "nintendo ds" => "nds",
    "wonderswan" => "wonderswan",
    "32x" => "32x",
    "sega cd" => "segacd"
  }

  @doc """
  Normalizes a RetroAchievements console name to a short platform slug.
  Returns "retroachievements" for nil (unknown/missing console).
  For unknown consoles, falls back to a slugified lowercase name (spaces removed),
  which may generate new platform values not yet in the console map.
  """
  def normalize_console(nil), do: "retroachievements"
  def normalize_console(name) do
    key = String.downcase(name)
    Map.get(@console_map, key, String.replace(key, " ", ""))
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id} = args}) do
    ra_opts =
      case args["ra_base_url"] do
        nil -> []
        url -> [base_url: url]
      end

    with conn when not is_nil(conn) <- get_ra_connection(user_id),
         {:ok, games} <- RetroClient.get_user_games(conn.external_id, conn.api_key, ra_opts) do
      new_count =
        Enum.reduce(games, 0, fn game_summary, total_new ->
          case RetroClient.get_game_progress(conn.external_id, conn.api_key, game_summary.game_id, ra_opts) do
            {:ok, game_detail} -> sync_game(user_id, game_summary, game_detail) + total_new
            {:error, _} -> total_new
          end
        end)

      Notifications.broadcast_new_achievements(user_id, new_count)
      :ok
    else
      nil -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_ra_connection(user_id) do
    import Ecto.Query
    Repo.one(
      from pc in AchievTrack.Accounts.PlatformConnection,
      where: pc.user_id == ^user_id and pc.platform == "retroachievements"
    )
  end

  defp sync_game(user_id, summary, detail) do
    platform = normalize_console(detail.console_name)

    {:ok, game} = Catalog.upsert_game(%{
      platform: platform,
      external_id: to_string(detail.id),
      title: detail.title,
      image_url: "https://retroachievements.org#{detail.image_icon}",
      total_achievements: detail.num_achievements
    })

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    ach_rows =
      detail.achievements
      |> Enum.reduce([], fn ach_data, acc ->
        {:ok, ach} = Catalog.upsert_achievement(%{
          game_id: game.id,
          external_id: to_string(ach_data.id),
          title: ach_data.title,
          description: ach_data.description,
          points: ach_data.points,
          image_url: "https://s3-eu-west-1.amazonaws.com/i.retroachievements.org/Badge/#{ach_data.badge_name}.png"
        })

        case ach_data.date_earned do
          nil -> acc
          date_str ->
            unlocked_at = parse_ra_date(date_str) || now
            [%{user_id: user_id, achievement_id: ach.id, unlocked_at: unlocked_at} | acc]
        end
      end)

    Catalog.upsert_user_game(%{
      user_id: user_id,
      game_id: game.id,
      playtime_forever: 0,
      unlocked_count: summary.num_awarded,
      is_beaten: summary.max_possible > 0 and summary.num_awarded >= div(summary.max_possible, 2),
      is_mastered: summary.max_possible > 0 and summary.num_awarded == summary.max_possible,
      last_synced_at: now
    })

    {new_count, _} = Catalog.insert_user_achievements(ach_rows)
    new_count
  end

  defp parse_ra_date(nil), do: nil
  defp parse_ra_date(date_str) do
    case NaiveDateTime.from_iso8601(String.replace(date_str, " ", "T")) do
      {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
      _ -> nil
    end
  end
end
