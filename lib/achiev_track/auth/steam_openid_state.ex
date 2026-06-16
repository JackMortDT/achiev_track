defmodule AchievTrack.Auth.SteamOpenIDState do
  use GenServer

  @default_ttl 300  # 5 minutes in seconds
  @table :steam_openid_state

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def put(state_token, user_id, opts \\ []) do
    ttl = Keyword.get(opts, :ttl_seconds, @default_ttl)
    expires_at = System.system_time(:second) + ttl
    :ets.insert(@table, {state_token, user_id, expires_at})
  end

  def pop(state_token) do
    now = System.system_time(:second)
    case :ets.take(@table, state_token) do
      [{^state_token, user_id, expires_at}] when expires_at > now ->
        {:ok, user_id}
      _ ->
        :error
    end
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set])
    {:ok, %{}}
  end
end
