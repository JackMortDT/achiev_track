# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :achiev_track,
  ecto_repos: [AchievTrack.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :achiev_track, AchievTrackWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: AchievTrackWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AchievTrack.PubSub,
  live_view: [signing_salt: "jzJYNHfs"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :achiev_track, AchievTrack.Repo,
  migration_primary_key: [type: :binary_id],
  migration_foreign_key: [type: :binary_id]

config :achiev_track, AchievTrack.Auth.Guardian,
  issuer: "achiev_track",
  secret_key: System.get_env("GUARDIAN_SECRET") || "dev_secret_change_in_prod"

config :cors_plug,
  origin: [System.get_env("FRONTEND_URL") || "http://localhost:3000"],
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  headers: ["Authorization", "Content-Type", "Accept"]

config :achiev_track, Oban,
  repo: AchievTrack.Repo,
  peer: Oban.Peers.Global,
  queues: [sync: 10],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * *", AchievTrack.Sync.DailySchedulerWorker}
     ]}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
