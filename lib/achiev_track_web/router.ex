defmodule AchievTrackWeb.Router do
  use AchievTrackWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", AchievTrackWeb do
    pipe_through :api
  end

end
