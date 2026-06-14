defmodule AchievTrack.Sync.DailySchedulerWorker do
  use Oban.Worker, queue: :sync

  import Ecto.Query
  alias AchievTrack.Repo
  alias AchievTrack.Accounts.PlatformConnection
  alias AchievTrack.Sync.{SteamWorker, RetroWorker}

  @impl Oban.Worker
  def perform(_job) do
    user_ids =
      Repo.all(from pc in PlatformConnection, select: pc.user_id, distinct: true)

    Enum.each(user_ids, fn user_id ->
      Oban.insert(SteamWorker.new(%{"user_id" => user_id}))
      Oban.insert(RetroWorker.new(%{"user_id" => user_id}))
    end)

    :ok
  end
end
