defmodule AchievTrack.Auth.GoogleOAuth do
  @auth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"
  @userinfo_url "https://www.googleapis.com/oauth2/v2/userinfo"

  defp client_id, do: Application.fetch_env!(:achiev_track, :google_client_id)
  defp client_secret, do: Application.fetch_env!(:achiev_track, :google_client_secret)
  defp redirect_uri, do: "#{Application.fetch_env!(:achiev_track, :backend_url)}/auth/google/callback"

  def redirect_url(state_token) do
    params = %{
      "client_id" => client_id(),
      "redirect_uri" => redirect_uri(),
      "response_type" => "code",
      "scope" => "openid email profile",
      "state" => state_token,
      "access_type" => "online"
    }

    "#{@auth_url}?" <> URI.encode_query(params)
  end

  def exchange_code(code) do
    body =
      URI.encode_query(%{
        "code" => code,
        "client_id" => client_id(),
        "client_secret" => client_secret(),
        "redirect_uri" => redirect_uri(),
        "grant_type" => "authorization_code"
      })

    case Finch.build(:post, @token_url, [{"content-type", "application/x-www-form-urlencoded"}], body)
         |> Finch.request(AchievTrack.Finch) do
      {:ok, %Finch.Response{status: 200, body: resp_body}} ->
        {:ok, Jason.decode!(resp_body)}

      {:ok, %Finch.Response{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end

  def get_user_info(access_token) do
    headers = [{"authorization", "Bearer #{access_token}"}]

    case Finch.build(:get, @userinfo_url, headers)
         |> Finch.request(AchievTrack.Finch) do
      {:ok, %Finch.Response{status: 200, body: resp_body}} ->
        data = Jason.decode!(resp_body)
        {:ok,
         %{
           google_id: data["id"],
           email: data["email"],
           name: data["name"],
           avatar_url: data["picture"]
         }}

      {:ok, %Finch.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end
end
