defmodule AchievTrack.Auth.SteamOpenID do
  @steam_openid_url "https://steamcommunity.com/openid/login"
  @steam_id_pattern ~r|https://steamcommunity\.com/openid/id/(\d+)|

  def redirect_url(realm, state_token, opts \\ []) do
    base = Keyword.get(opts, :base_url, @steam_openid_url)
    return_to = "#{realm}/auth/steam/callback?state=#{state_token}"

    params = %{
      "openid.ns" => "http://specs.openid.net/auth/2.0",
      "openid.mode" => "checkid_setup",
      "openid.return_to" => return_to,
      "openid.realm" => realm,
      "openid.identity" => "http://specs.openid.net/auth/2.0/identifier_select",
      "openid.claimed_id" => "http://specs.openid.net/auth/2.0/identifier_select"
    }

    "#{base}?" <> URI.encode_query(params)
  end

  def extract_steam_id(%{"openid.mode" => "cancel"}), do: {:error, :cancelled}

  def extract_steam_id(%{"openid.claimed_id" => claimed_id}) do
    case Regex.run(@steam_id_pattern, claimed_id) do
      [_, steam_id] when steam_id != "" -> {:ok, steam_id}
      _ -> {:error, :invalid_claimed_id}
    end
  end

  def extract_steam_id(_), do: {:error, :invalid_claimed_id}

  def verify(params, opts \\ []) do
    url =
      case Keyword.get(opts, :base_url) do
        nil -> @steam_openid_url
        base -> "#{base}/openid/login"
      end

    verify_params = Map.put(params, "openid.mode", "check_authentication")
    body = URI.encode_query(verify_params)

    case Finch.build(:post, url, [{"content-type", "application/x-www-form-urlencoded"}], body)
         |> Finch.request(AchievTrack.Finch) do
      {:ok, %Finch.Response{status: 200, body: resp_body}} ->
        if String.contains?(resp_body, "is_valid:true"), do: :ok, else: {:error, :invalid_signature}

      {:ok, %Finch.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end
end
