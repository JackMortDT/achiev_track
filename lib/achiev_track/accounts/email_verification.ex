defmodule AchievTrack.Accounts.EmailVerification do
  import Ecto.Query
  alias AchievTrack.{Repo, Accounts.User, Mailer}

  @token_expiry_seconds 24 * 60 * 60
  @resend_cooldown_seconds 5 * 60

  def generate_token(user) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    hashed = hash_token(token)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    user
    |> Ecto.Changeset.change(
      email_verification_token: hashed,
      email_verification_sent_at: now
    )
    |> Repo.update!()

    {:ok, token}
  end

  def generate_and_send(user) do
    {:ok, token} = generate_token(user)
    Mailer.send_verification_email(user, token)
    :ok
  end

  def verify(token) do
    hashed = hash_token(token)
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, -@token_expiry_seconds, :second)

    case Repo.one(
      from u in User,
        where: u.email_verification_token == ^hashed
          and u.email_verification_sent_at >= ^cutoff
          and is_nil(u.email_verified_at)
    ) do
      nil ->
        {:error, :invalid_or_expired}

      user ->
        user
        |> Ecto.Changeset.change(
          email_verified_at: DateTime.truncate(now, :second),
          email_verification_token: nil
        )
        |> Repo.update()
    end
  end

  def resend(user) do
    if too_soon?(user) do
      {:error, :too_soon}
    else
      generate_and_send(user)
    end
  end

  def verified?(%User{email_verified_at: nil}), do: false
  def verified?(%User{}), do: true

  defp too_soon?(%User{email_verification_sent_at: nil}), do: false
  defp too_soon?(%User{email_verification_sent_at: sent_at}) do
    cutoff = DateTime.add(DateTime.utc_now(), -@resend_cooldown_seconds, :second)
    DateTime.compare(sent_at, cutoff) == :gt
  end

  defp hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
  end
end
