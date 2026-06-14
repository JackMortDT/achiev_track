defmodule AchievTrackWeb.Router do
  use AchievTrackWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug
  end

  pipeline :auth do
    plug AchievTrackWeb.Plugs.AuthPipeline
  end

  scope "/api", AchievTrackWeb do
    pipe_through :api

    post "/register", AuthController, :register
    post "/login", AuthController, :login
  end

  scope "/api", AchievTrackWeb do
    pipe_through [:api, :auth]

    get "/me", UserController, :show
    post "/me/platforms", UserController, :connect_platform
    delete "/me/platforms/:platform", UserController, :disconnect_platform

    get "/sync/status", SyncController, :status
    post "/sync", SyncController, :trigger
    get "/events", EventsController, :subscribe

    get "/profile", ProfileController, :show
    get "/achievements", AchievementsController, :index
    get "/games", GamesController, :index

    get "/friends/leaderboard", FriendsController, :leaderboard
    get "/friends/pending", FriendsController, :pending
    get "/friends/:user_id/compare", FriendsController, :compare
    resources "/friends", FriendsController, only: [:index, :create, :delete]
    put "/friends/:id/accept", FriendsController, :accept
  end
end
