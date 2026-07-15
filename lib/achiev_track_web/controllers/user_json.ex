defmodule AchievTrackWeb.UserJSON do
  def show(%{user: user}) do
    %{
      id: user.id,
      username: user.username,
      email: user.email,
      avatar_url: user.avatar_url,
      inserted_at: user.inserted_at,
      email_verified: not is_nil(user.email_verified_at),
      platform_connections: Enum.map(user.platform_connections, &platform_connection_data/1)
    }
  end

  def platform_connection(%{connection: connection}) do
    platform_connection_data(connection)
  end

  def errors(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  defp platform_connection_data(conn) do
    %{
      platform: conn.platform,
      external_id: conn.external_id,
      connected_at: conn.inserted_at
    }
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
