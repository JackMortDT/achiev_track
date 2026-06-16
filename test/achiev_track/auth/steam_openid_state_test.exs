defmodule AchievTrack.Auth.SteamOpenIDStateTest do
  use ExUnit.Case, async: false

  alias AchievTrack.Auth.SteamOpenIDState

  setup do
    # The app supervisor may have already started the named GenServer.
    # Start it if not running, otherwise reuse the existing process.
    pid =
      case SteamOpenIDState.start_link([]) do
        {:ok, pid} ->
          on_exit(fn -> Process.exit(pid, :kill) end)
          pid

        {:error, {:already_started, pid}} ->
          pid
      end

    # Clear the ETS table before each test for isolation
    :ets.delete_all_objects(:steam_openid_state)

    %{pid: pid}
  end

  test "stores and retrieves a state token" do
    SteamOpenIDState.put("token-abc", "user-123")
    assert {:ok, "user-123"} = SteamOpenIDState.pop("token-abc")
  end

  test "pop removes the token (can only be used once)" do
    SteamOpenIDState.put("token-once", "user-456")
    assert {:ok, "user-456"} = SteamOpenIDState.pop("token-once")
    assert :error = SteamOpenIDState.pop("token-once")
  end

  test "returns :error for unknown token" do
    assert :error = SteamOpenIDState.pop("nonexistent")
  end

  test "returns :error for expired token" do
    SteamOpenIDState.put("token-expired", "user-789", ttl_seconds: 0)
    Process.sleep(10)
    assert :error = SteamOpenIDState.pop("token-expired")
  end
end
