defmodule AchievTrack.AccountsTest do
  use AchievTrack.DataCase

  alias AchievTrack.Accounts.User
  alias AchievTrack.Accounts.PlatformConnection

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

  describe "Accounts.register_user/1" do
    test "creates user with valid attrs and UUID id" do
      attrs = %{username: "player_one", email: "player@example.com", password: "secret123"}
      assert {:ok, user} = AchievTrack.Accounts.register_user(attrs)
      assert user.email == "player@example.com"
      assert user.username == "player_one"
      assert user.password_hash != nil
      assert is_binary(user.id)
      # UUID format: 8-4-4-4-12 hex chars
      assert String.match?(user.id, ~r/^[0-9a-f\-]{36}$/)
    end

    test "returns error with duplicate email" do
      attrs = %{username: "player_one", email: "dup@example.com", password: "secret123"}
      {:ok, _} = AchievTrack.Accounts.register_user(attrs)
      attrs2 = %{username: "player_two", email: "dup@example.com", password: "secret123"}
      assert {:error, changeset} = AchievTrack.Accounts.register_user(attrs2)
      assert {"has already been taken", _} = Keyword.get(changeset.errors, :email)
    end

    test "returns error with invalid attrs" do
      assert {:error, changeset} = AchievTrack.Accounts.register_user(%{})
      refute changeset.valid?
    end
  end

  describe "Accounts.authenticate_user/2" do
    setup do
      {:ok, user} = AchievTrack.Accounts.register_user(%{
        username: "auth_user",
        email: "auth@example.com",
        password: "secret123"
      })
      %{user: user}
    end

    test "returns user with correct credentials", %{user: user} do
      assert {:ok, returned} = AchievTrack.Accounts.authenticate_user("auth@example.com", "secret123")
      assert returned.id == user.id
    end

    test "returns error with wrong password" do
      assert {:error, :invalid_credentials} =
        AchievTrack.Accounts.authenticate_user("auth@example.com", "wrongpass")
    end

    test "returns error with unknown email" do
      assert {:error, :invalid_credentials} =
        AchievTrack.Accounts.authenticate_user("nobody@example.com", "secret123")
    end
  end

  describe "PlatformConnection.changeset/2" do
    test "valid steam connection" do
      user_id = Ecto.UUID.generate()
      attrs = %{user_id: user_id, platform: "steam", external_id: "76561198000000000"}
      changeset = PlatformConnection.changeset(%PlatformConnection{}, attrs)
      assert changeset.valid?
    end

    test "valid retroachievements connection" do
      user_id = Ecto.UUID.generate()
      attrs = %{user_id: user_id, platform: "retroachievements", external_id: "player_one", api_key: "abc123"}
      changeset = PlatformConnection.changeset(%PlatformConnection{}, attrs)
      assert changeset.valid?
    end

    test "invalid platform name is rejected" do
      user_id = Ecto.UUID.generate()
      attrs = %{user_id: user_id, platform: "psn", external_id: "id123"}
      changeset = PlatformConnection.changeset(%PlatformConnection{}, attrs)
      refute changeset.valid?
    end

    test "missing external_id is invalid" do
      user_id = Ecto.UUID.generate()
      attrs = %{user_id: user_id, platform: "steam"}
      changeset = PlatformConnection.changeset(%PlatformConnection{}, attrs)
      refute changeset.valid?
    end
  end

  describe "upsert_steam_connection/2" do
    setup do
      {:ok, user} = AchievTrack.Accounts.register_user(%{
        username: "steam_acc",
        email: "steamacc@example.com",
        password: "secret123"
      })
      %{user: user}
    end

    test "creates a new steam platform_connection", %{user: user} do
      assert {:ok, conn} = AchievTrack.Accounts.upsert_steam_connection(user.id, "76561198000000001")
      assert conn.platform == "steam"
      assert conn.external_id == "76561198000000001"
      assert conn.api_key == nil
    end

    test "updates external_id if connection already exists", %{user: user} do
      {:ok, _} = AchievTrack.Accounts.upsert_steam_connection(user.id, "76561198000000001")
      {:ok, updated} = AchievTrack.Accounts.upsert_steam_connection(user.id, "76561198000000002")
      assert updated.external_id == "76561198000000002"

      import Ecto.Query
      count = AchievTrack.Repo.aggregate(
        from(pc in AchievTrack.Accounts.PlatformConnection,
          where: pc.user_id == ^user.id and pc.platform == "steam"),
        :count
      )
      assert count == 1
    end
  end

  describe "find_or_create_by_steam/1" do
    test "creates a new user when steam_id is unknown" do
      assert {:ok, user} = AchievTrack.Accounts.find_or_create_by_steam("76561198000000001")
      assert user.username == "steam_76561198000000001"
      assert is_nil(user.email)
      assert is_nil(user.password_hash)

      conn = AchievTrack.Repo.get_by(AchievTrack.Accounts.PlatformConnection,
        platform: "steam", external_id: "76561198000000001")
      assert conn.user_id == user.id
    end

    test "returns existing user when steam_id is already linked" do
      {:ok, user1} = AchievTrack.Accounts.find_or_create_by_steam("76561198000000002")
      {:ok, user2} = AchievTrack.Accounts.find_or_create_by_steam("76561198000000002")
      assert user1.id == user2.id
    end
  end

  describe "find_or_create_by_google/1" do
    test "creates a new user when google_id is unknown" do
      info = %{google_id: "g-001", email: "new@gmail.com", name: "Test User", avatar_url: nil}
      assert {:ok, user} = AchievTrack.Accounts.find_or_create_by_google(info)
      assert user.google_id == "g-001"
      assert user.email == "new@gmail.com"
      assert is_nil(user.password_hash)
    end

    test "returns existing user when google_id matches" do
      info = %{google_id: "g-002", email: "dup@gmail.com", name: "Dup User", avatar_url: nil}
      {:ok, user1} = AchievTrack.Accounts.find_or_create_by_google(info)
      {:ok, user2} = AchievTrack.Accounts.find_or_create_by_google(info)
      assert user1.id == user2.id
    end

    test "links google to existing email account" do
      {:ok, existing} = AchievTrack.Accounts.register_user(%{
        username: "emailuser",
        email: "linked@gmail.com",
        password: "secret123"
      })
      info = %{google_id: "g-003", email: "linked@gmail.com", name: "Email User", avatar_url: nil}
      {:ok, user} = AchievTrack.Accounts.find_or_create_by_google(info)
      assert user.id == existing.id
      assert user.google_id == "g-003"
    end
  end
end
