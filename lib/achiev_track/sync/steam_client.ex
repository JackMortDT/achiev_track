defmodule AchievTrack.Sync.SteamClient do
  @default_base_url "https://api.steampowered.com"

  def get_owned_games(api_key, steam_id, opts \\ []) do
    base = Keyword.get(opts, :base_url, @default_base_url)
    url = "#{base}/IPlayerService/GetOwnedGames/v1/"
    params = [key: api_key, steamid: steam_id, include_appinfo: 1, format: "json"]

    case request(url, params) do
      {:ok, %{"response" => response}} ->
        games =
          (response["games"] || [])
          |> Enum.map(fn g ->
            %{
              appid: g["appid"],
              name: g["name"],
              img_icon_url: g["img_icon_url"],
              playtime_forever: g["playtime_forever"] || 0
            }
          end)
        {:ok, games}

      {:error, _} = err ->
        err
    end
  end

  def get_player_achievements(api_key, steam_id, app_id, opts \\ []) do
    base = Keyword.get(opts, :base_url, @default_base_url)
    url = "#{base}/ISteamUserStats/GetPlayerAchievements/v1/"
    params = [key: api_key, steamid: steam_id, appid: app_id, l: "en", format: "json"]

    case request(url, params) do
      {:ok, %{"playerstats" => playerstats}} ->
        if playerstats["success"] == false do
          {:ok, []}
        else
          achievements =
            (playerstats["achievements"] || [])
            |> Enum.map(fn a ->
              %{
                apiname: a["apiname"],
                achieved: a["achieved"],
                unlocktime: a["unlocktime"],
                name: a["name"],
                description: a["description"]
              }
            end)
          {:ok, achievements}
        end

      {:error, _} = err ->
        err
    end
  end

  def get_game_schema(api_key, app_id, opts \\ []) do
    base = Keyword.get(opts, :base_url, @default_base_url)
    url = "#{base}/ISteamUserStats/GetSchemaForGame/v2/"
    params = [key: api_key, appid: app_id, format: "json"]

    case request(url, params) do
      {:ok, %{"game" => game}} ->
        achievements = get_in(game, ["availableGameStats", "achievements"]) || []
        schema =
          Map.new(achievements, fn a ->
            icon_url =
              case a["icon"] do
                nil -> nil
                "" -> nil
                icon when binary_part(icon, 0, 4) == "http" -> icon
                icon -> "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/apps/#{app_id}/#{icon}.jpg"
              end
            {a["name"], icon_url}
          end)
        {:ok, schema}

      {:error, _} = err ->
        err
    end
  end

  def get_store_header_image(app_id) do
    url = "https://store.steampowered.com/api/appdetails?appids=#{app_id}&filters=basic"

    case Finch.build(:get, url) |> Finch.request(AchievTrack.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        with {:ok, decoded} <- Jason.decode(body),
             %{"success" => true, "data" => %{"header_image" => img}} <- decoded[to_string(app_id)] do
          {:ok, img}
        else
          _ -> {:error, :not_found}
        end

      _ -> {:error, :not_found}
    end
  end

  def get_player_summary(api_key, steam_id, opts \\ []) do
    base = Keyword.get(opts, :base_url, @default_base_url)
    url = "#{base}/ISteamUser/GetPlayerSummaries/v2/"
    params = [key: api_key, steamids: steam_id, format: "json"]

    case request(url, params) do
      {:ok, %{"response" => %{"players" => [player | _]}}} ->
        {:ok, %{
          username: player["personaname"],
          avatar_url: player["avatarfull"]
        }}

      {:ok, _} ->
        {:error, :not_found}

      {:error, _} = err ->
        err
    end
  end

  defp request(url, params) do
    query = URI.encode_query(params)
    full_url = "#{url}?#{query}"

    case Finch.build(:get, full_url) |> Finch.request(AchievTrack.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, :invalid_json}
        end

      {:ok, %Finch.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end
end
