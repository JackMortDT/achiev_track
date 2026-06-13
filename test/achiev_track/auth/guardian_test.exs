defmodule AchievTrack.Auth.GuardianTest do
  use AchievTrack.DataCase

  alias AchievTrack.Auth.Guardian
  alias AchievTrack.Accounts

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "jwt_user",
      email: "jwt@example.com",
      password: "secret123"
    })
    %{user: user}
  end

  test "encode and decode token for user", %{user: user} do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    assert is_binary(token)

    {:ok, decoded_user, _claims} = Guardian.resource_from_token(token)
    assert decoded_user.id == user.id
  end

  test "subject_for_token returns string UUID", %{user: user} do
    {:ok, sub} = Guardian.subject_for_token(user, %{})
    assert sub == user.id
    assert String.match?(sub, ~r/^[0-9a-f\-]{36}$/)
  end

  test "resource_from_claims fetches user by UUID", %{user: user} do
    {:ok, fetched} = Guardian.resource_from_claims(%{"sub" => user.id})
    assert fetched.id == user.id
  end
end
