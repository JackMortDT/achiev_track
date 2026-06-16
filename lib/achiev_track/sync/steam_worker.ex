defmodule AchievTrack.Sync.SteamWorker do
  use Oban.Worker, queue: :sync

  alias AchievTrack.{Catalog, Notifications, Repo}
  alias AchievTrack.Sync.SteamClient

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id} = args}) do
    steam_opts =
      case args["steam_base_url"] do
        nil -> []
        url -> [base_url: url]
      end

    with conn when not is_nil(conn) <- get_steam_connection(user_id) do
      api_key = conn.api_key || Application.get_env(:achiev_track, :steam_api_key)

      with {:ok, games} <- SteamClient.get_owned_games(api_key, conn.external_id, steam_opts) do
        new_achievement_count =
          games
          |> Enum.filter(&(&1.playtime_forever > 0))
          |> Task.async_stream(
            fn game_data -> sync_game(user_id, game_data, api_key, conn.external_id, steam_opts) end,
            max_concurrency: 5,
            timeout: 30_000,
            on_timeout: :kill_task
          )
          |> Enum.reduce(0, fn
            {:ok, count}, total -> total + count
            _, total -> total
          end)

        Notifications.broadcast_new_achievements(user_id, new_achievement_count)
        :ok
      end
    else
      nil -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_steam_connection(user_id) do
    import Ecto.Query
    Repo.one(
      from pc in AchievTrack.Accounts.PlatformConnection,
      where: pc.user_id == ^user_id and pc.platform == "steam"
    )
  end

  defp sync_game(user_id, game_data, api_key, steam_id, opts) do
    {:ok, game} = Catalog.upsert_game(%{
      platform: "steam",
      external_id: to_string(game_data.appid),
      title: game_data.name,
      image_url: steam_icon_url(game_data.appid, game_data.img_icon_url),
      total_achievements: 0
    })

    schema =
      case SteamClient.get_game_schema(api_key, game_data.appid, opts) do
        {:ok, s} -> s
        _ -> %{}
      end

    case SteamClient.get_player_achievements(api_key, steam_id, game_data.appid, opts) do
      {:ok, []} -> 0
      {:error, _} -> 0

      {:ok, achievements} ->
        {:ok, _} = Catalog.upsert_game(%{
          platform: "steam",
          external_id: to_string(game_data.appid),
          title: game_data.name,
          total_achievements: length(achievements)
        })

        now = DateTime.utc_now() |> DateTime.truncate(:second)

        ach_map =
          Map.new(achievements, fn a ->
            {:ok, ach} = Catalog.upsert_achievement(%{
              game_id: game.id,
              external_id: a.apiname,
              title: a.name,
              description: a.description,
              points: 0,
              image_url: schema[a.apiname]
            })
            {a.apiname, ach}
          end)

        unlocked = Enum.filter(achievements, &(&1.achieved == 1))

        ach_rows =
          Enum.map(unlocked, fn a ->
            ach = ach_map[a.apiname]
            unlocked_at =
              if a.unlocktime && a.unlocktime > 0 do
                DateTime.from_unix!(a.unlocktime) |> DateTime.truncate(:second)
              else
                now
              end
            %{user_id: user_id, achievement_id: ach.id, unlocked_at: unlocked_at}
          end)

        upsert_user_game(user_id, game.id, length(unlocked), length(achievements))
        {new_count, _} = Catalog.insert_user_achievements(ach_rows)
        new_count
    end
  end

  defp upsert_user_game(user_id, game_id, unlocked, total) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Catalog.upsert_user_game(%{
      user_id: user_id,
      game_id: game_id,
      unlocked_count: unlocked,
      is_beaten: unlocked > 0 and unlocked >= div(total, 2),
      is_mastered: total > 0 and unlocked == total,
      last_synced_at: now
    })
  end

  defp steam_icon_url(_appid, ""), do: nil
  defp steam_icon_url(_appid, nil), do: nil
  defp steam_icon_url(appid, icon_hash) do
    "https://media.steampowered.com/steamcommunity/public/images/apps/#{appid}/#{icon_hash}.jpg"
  end
end
