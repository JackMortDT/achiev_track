defmodule AchievTrackWeb.FriendsJSON do
  def index(%{friends: friends}) do
    Enum.map(friends, &friend_entry/1)
  end

  def leaderboard(%{entries: entries, current_user_id: current_user_id}) do
    Enum.map(entries, fn e ->
      %{
        rank: e.rank,
        user_id: e.user_id,
        username: e.username,
        avatar_url: e.avatar_url,
        total_points: e.total_points,
        is_me: e.user_id == current_user_id
      }
    end)
  end

  def compare(%{data: data}) do
    %{
      user: data.user,
      friend: data.friend,
      shared_games: Enum.map(data.shared_games, fn g ->
        %{
          title: g.title,
          platform: g.platform,
          user_unlocked: g.user_unlocked,
          friend_unlocked: g.friend_unlocked,
          total: g.total
        }
      end)
    }
  end

  defp friend_entry(f) do
    %{
      friendship_id: f.friendship_id,
      user_id: f.user_id,
      username: f.username,
      avatar_url: f.avatar_url,
      status: f.status
    }
  end
end
