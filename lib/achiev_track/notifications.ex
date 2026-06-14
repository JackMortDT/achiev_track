defmodule AchievTrack.Notifications do
  @pubsub AchievTrack.PubSub
  @topic_prefix "sync"

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(user_id))
  end

  def broadcast_new_achievements(user_id, count) when count > 0 do
    Phoenix.PubSub.broadcast(@pubsub, topic(user_id), {:new_achievements, count})
  end

  def broadcast_new_achievements(_user_id, 0), do: :ok

  defp topic(user_id), do: "#{@topic_prefix}:#{user_id}"
end
