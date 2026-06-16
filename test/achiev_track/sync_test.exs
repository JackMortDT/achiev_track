defmodule AchievTrack.SyncTest do
  use AchievTrack.DataCase

  alias AchievTrack.Sync
  alias AchievTrack.Accounts

  setup do
    {:ok, user} = Accounts.register_user(%{
      username: "sync_user",
      email: "sync@example.com",
      password: "secret123"
    })
    %{user: user}
  end

  describe "Sync.rate_limit_status/1" do
    setup do
      %{limit: Application.get_env(:achiev_track, :max_syncs_per_hour, 10)}
    end

    test "returns allowed with 0 syncs used when no records", %{user: user, limit: limit} do
      status = Sync.rate_limit_status(user.id)
      assert status.allowed == true
      assert status.syncs_used == 0
      assert status.syncs_remaining == limit
      assert status.next_available_at == nil
    end

    test "returns allowed with 2 syncs used after 2 records", %{user: user, limit: limit} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Sync.record_sync(user.id, now)
      Sync.record_sync(user.id, now)
      status = Sync.rate_limit_status(user.id)
      assert status.allowed == true
      assert status.syncs_used == 2
      assert status.syncs_remaining == limit - 2
    end

    test "returns not allowed after limit records within 1 hour", %{user: user, limit: limit} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Enum.each(1..limit, fn _ -> Sync.record_sync(user.id, now) end)
      status = Sync.rate_limit_status(user.id)
      assert status.allowed == false
      assert status.syncs_used == limit
      assert status.syncs_remaining == 0
      assert %DateTime{} = status.next_available_at
      assert DateTime.compare(status.next_available_at, DateTime.utc_now()) == :gt
      assert DateTime.diff(status.next_available_at, DateTime.utc_now()) <= 3600
    end

    test "does not count records older than 1 hour", %{user: user} do
      old = DateTime.utc_now() |> DateTime.add(-3700, :second) |> DateTime.truncate(:second)
      Sync.record_sync(user.id, old)
      Sync.record_sync(user.id, old)
      Sync.record_sync(user.id, old)
      status = Sync.rate_limit_status(user.id)
      assert status.allowed == true
      assert status.syncs_used == 0
    end
  end

  describe "Sync.record_sync/2" do
    test "inserts a sync_rate_limit row", %{user: user} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      assert {:ok, _} = Sync.record_sync(user.id, now)
      status = Sync.rate_limit_status(user.id)
      assert status.syncs_used == 1
    end
  end
end
