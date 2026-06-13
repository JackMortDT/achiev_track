defmodule AchievTrack.Repo do
  use Ecto.Repo,
    otp_app: :achiev_track,
    adapter: Ecto.Adapters.Postgres

  # All tables use UUIDs as primary keys by default
  def default_options(_operation) do
    [returning: true]
  end
end
