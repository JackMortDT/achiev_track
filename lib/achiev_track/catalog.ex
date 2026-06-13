defmodule AchievTrack.Catalog do
  import Ecto.Query

  alias AchievTrack.Repo
  alias AchievTrack.Catalog.{Game, Achievement, UserGame, UserAchievement}

  def upsert_game(attrs) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:title, :image_url, :total_achievements, :updated_at]},
      conflict_target: [:platform, :external_id],
      returning: true
    )
  end

  def upsert_achievement(attrs) do
    %Achievement{}
    |> Achievement.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:title, :description, :points, :image_url, :updated_at]},
      conflict_target: [:game_id, :external_id],
      returning: true
    )
  end

  def upsert_user_game(attrs) do
    %UserGame{}
    |> UserGame.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:unlocked_count, :is_beaten, :is_mastered, :last_synced_at, :updated_at]},
      conflict_target: [:user_id, :game_id],
      returning: true
    )
  end

  # Inserts rows, skips duplicates. Returns {new_count, inserted_rows}.
  def insert_user_achievements([]), do: {0, []}

  def insert_user_achievements(rows) when is_list(rows) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    entries =
      Enum.map(rows, fn row ->
        Map.merge(row, %{
          id: Ecto.UUID.generate(),
          inserted_at: now,
          updated_at: now
        })
      end)

    Repo.insert_all(
      UserAchievement,
      entries,
      on_conflict: :nothing,
      conflict_target: [:user_id, :achievement_id],
      returning: [:id]
    )
  end

  def get_achievement_ids_for_user(user_id) do
    Repo.all(from ua in UserAchievement, where: ua.user_id == ^user_id, select: ua.achievement_id)
  end
end
