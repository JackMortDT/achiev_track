defmodule AchievTrack.Auth.Guardian do
  use Guardian, otp_app: :achiev_track

  alias AchievTrack.Accounts

  # UUIDs are already strings — no need to convert
  def subject_for_token(user, _claims) do
    {:ok, user.id}
  end

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end
end
