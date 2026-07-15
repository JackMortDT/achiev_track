defmodule AchievTrack.Accounts.EmailVerificationTest do
  use AchievTrack.DataCase
  import Swoosh.TestAssertions

  alias AchievTrack.{Accounts, Accounts.EmailVerification}

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "verifyuser",
      email: "verify@example.com",
      password: "secret123"
    })
    %{user: user}
  end

  test "generate_and_send/1 sends a verification email", %{user: user} do
    assert :ok = EmailVerification.generate_and_send(user)
    assert_email_sent(subject: "Verifica tu email — RetroPlatform", to: {user.username, user.email})
  end

  test "generate_and_send/1 stores a hashed token on the user", %{user: user} do
    EmailVerification.generate_and_send(user)
    updated = AchievTrack.Repo.get!(AchievTrack.Accounts.User, user.id)
    assert updated.email_verification_token != nil
    assert updated.email_verification_sent_at != nil
    assert updated.email_verified_at == nil
  end

  test "verify/1 marks user as verified with a valid token", %{user: user} do
    {:ok, token} = EmailVerification.generate_token(user)
    {:ok, verified_user} = EmailVerification.verify(token)
    assert verified_user.email_verified_at != nil
    assert verified_user.email_verification_token == nil
  end

  test "verify/1 returns error for invalid token", %{user: _user} do
    assert {:error, :invalid_or_expired} = EmailVerification.verify("badtoken")
  end

  test "resend/1 returns error if sent less than 5 minutes ago", %{user: user} do
    EmailVerification.generate_and_send(user)
    updated = AchievTrack.Repo.get!(AchievTrack.Accounts.User, user.id)
    assert {:error, :too_soon} = EmailVerification.resend(updated)
  end

  test "verified user is detected as verified", %{user: user} do
    {:ok, token} = EmailVerification.generate_token(user)
    EmailVerification.verify(token)
    updated = AchievTrack.Repo.get!(AchievTrack.Accounts.User, user.id)
    assert EmailVerification.verified?(updated)
  end
end
