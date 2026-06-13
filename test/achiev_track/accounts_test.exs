defmodule AchievTrack.AccountsTest do
  use AchievTrack.DataCase

  alias AchievTrack.Accounts.User

  describe "User.changeset/2" do
    test "valid attrs produce a valid changeset" do
      attrs = %{username: "player_one", email: "player@example.com", password: "secret123"}
      changeset = User.changeset(%User{}, attrs)
      assert changeset.valid?
    end

    test "missing email is invalid" do
      attrs = %{username: "player_one", password: "secret123"}
      changeset = User.changeset(%User{}, attrs)
      refute changeset.valid?
      assert {:email, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "missing username is invalid" do
      attrs = %{email: "player@example.com", password: "secret123"}
      changeset = User.changeset(%User{}, attrs)
      refute changeset.valid?
    end

    test "password too short is invalid" do
      attrs = %{username: "player_one", email: "player@example.com", password: "abc"}
      changeset = User.changeset(%User{}, attrs)
      refute changeset.valid?
    end

    test "password is hashed into password_hash" do
      attrs = %{username: "player_one", email: "player@example.com", password: "secret123"}
      changeset = User.changeset(%User{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :password_hash) != nil
      assert Ecto.Changeset.get_change(changeset, :password) == nil
    end
  end
end
