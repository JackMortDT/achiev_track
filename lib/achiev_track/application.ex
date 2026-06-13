defmodule AchievTrack.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AchievTrackWeb.Telemetry,
      AchievTrack.Repo,
      {DNSCluster, query: Application.get_env(:achiev_track, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AchievTrack.PubSub},
      # Start a worker by calling: AchievTrack.Worker.start_link(arg)
      # {AchievTrack.Worker, arg},
      # Start to serve requests, typically the last entry
      AchievTrackWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AchievTrack.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AchievTrackWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
