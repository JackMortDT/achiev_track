defmodule AchievTrackWeb.AuthJSON do
  def auth(%{user: user, token: token}) do
    %{
      token: token,
      user: %{
        id: user.id,
        username: user.username,
        email: user.email,
        avatar_url: user.avatar_url,
        inserted_at: user.inserted_at
      }
    }
  end

  def errors(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  def error(%{message: message}) do
    %{error: message}
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
