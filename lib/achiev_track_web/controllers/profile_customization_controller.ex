defmodule AchievTrackWeb.ProfileCustomizationController do
  use AchievTrackWeb, :controller
  alias AchievTrack.Profile
  alias AchievTrack.Auth.Guardian

  def set_favorite_game(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    case Profile.set_favorite_game(user.id, Map.get(params, "game_id")) do
      {:ok, _} -> json(conn, %{ok: true})
      {:error, :game_not_found} ->
        conn |> put_status(422) |> json(%{error: "Game not found in your library"})
    end
  end

  def set_game_showcase(conn, %{"game_ids" => game_ids}) when is_list(game_ids) do
    user = Guardian.Plug.current_resource(conn)
    case Profile.set_game_showcase(user.id, game_ids) do
      {:ok, _} -> json(conn, %{ok: true})
      {:error, :too_many_games} ->
        conn |> put_status(422) |> json(%{error: "Maximum 6 games allowed"})
      {:error, :game_not_found} ->
        conn |> put_status(422) |> json(%{error: "One or more games not in your library"})
    end
  end

  def set_game_showcase(conn, _params) do
    conn |> put_status(422) |> json(%{error: "game_ids must be a list"})
  end

  def set_achievement_showcase(conn, %{"user_achievement_ids" => ua_ids}) when is_list(ua_ids) do
    user = Guardian.Plug.current_resource(conn)
    case Profile.set_achievement_showcase(user.id, ua_ids) do
      {:ok, _} -> json(conn, %{ok: true})
      {:error, :too_many_achievements} ->
        conn |> put_status(422) |> json(%{error: "Maximum 5 achievements allowed"})
      {:error, :achievement_not_found} ->
        conn |> put_status(422) |> json(%{error: "One or more achievements not found"})
    end
  end

  def set_achievement_showcase(conn, _params) do
    conn |> put_status(422) |> json(%{error: "user_achievement_ids must be a list"})
  end
end
