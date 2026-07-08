defmodule AchievTrack.Sync.RetroClient do
  @default_base_url "https://retroachievements.org"

  def get_user_games(username, api_key, opts \\ []) do
    base = Keyword.get(opts, :base_url, @default_base_url)
    url = "#{base}/API/API_GetUserCompletionProgress.php"
    params = [z: username, y: api_key, u: username, c: 500, o: 0]

    case request(url, params, api_key) do
      {:ok, %{"Results" => results}} ->
        games =
          Enum.map(results, fn g ->
            %{
              game_id: g["GameID"],
              title: g["Title"],
              image_icon: g["ImageIcon"],
              num_awarded: g["NumAwarded"] || 0,
              max_possible: g["MaxPossible"] || 0
            }
          end)
        {:ok, games}

      {:error, _} = err ->
        err
    end
  end

  def get_game_progress(username, api_key, game_id, opts \\ []) do
    base = Keyword.get(opts, :base_url, @default_base_url)
    url = "#{base}/API/API_GetGameInfoAndUserProgress.php"
    params = [z: username, y: api_key, u: username, g: game_id]

    case request(url, params, api_key) do
      {:ok, body} ->
        achievements =
          (body["Achievements"] || %{})
          |> Map.values()
          |> Enum.map(fn a ->
            %{
              id: a["ID"],
              title: a["Title"],
              description: a["Description"],
              points: a["Points"] || 0,
              badge_name: a["BadgeName"],
              date_earned: a["DateEarned"]
            }
          end)

        game = %{
          id: body["ID"],
          title: body["Title"],
          console_name: body["ConsoleName"],
          image_icon: body["ImageIcon"],
          num_achievements: body["NumAchievements"] || 0,
          achievements: achievements
        }
        {:ok, game}

      {:error, _} = err ->
        err
    end
  end

  defp request(url, params, api_key) do
    query = URI.encode_query(params)
    full_url = "#{url}?#{query}"
    headers = [{"Authorization", "ApiKey #{api_key}"}]

    case Finch.build(:get, full_url, headers) |> Finch.request(AchievTrack.Finch) do
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
