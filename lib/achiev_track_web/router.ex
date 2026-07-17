defmodule AchievTrackWeb.Router do
  use AchievTrackWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug AchievTrackWeb.Plugs.DynamicCORS
  end

  pipeline :auth do
    plug AchievTrackWeb.Plugs.AuthPipeline
  end

  scope "/", AchievTrackWeb do
    pipe_through :api
    get "/auth/steam/callback", SteamAuthController, :callback
    get "/auth/google/callback", GoogleAuthController, :callback
  end

  scope "/api", AchievTrackWeb do
    pipe_through :api

    options "/*path", AuthController, :options
    post "/register", AuthController, :register
    post "/login", AuthController, :login
    delete "/logout", AuthController, :logout
    get "/verify-email/:token", AuthController, :verify_email
    get "/auth/steam/login", SteamAuthController, :login
    get "/auth/google/login", GoogleAuthController, :login
  end

  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :api
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  scope "/api", AchievTrackWeb do
    pipe_through [:api, :auth]

    get "/auth/steam/initiate", SteamAuthController, :initiate
    post "/resend-verification", AuthController, :resend_verification

    get "/me", UserController, :show
    patch "/me", UserController, :update
    patch "/me/password", UserController, :update_password
    delete "/me", UserController, :delete
    post "/me/platforms", UserController, :connect_platform
    delete "/me/platforms/:platform", UserController, :disconnect_platform

    get "/sync/status", SyncController, :status
    post "/sync", SyncController, :trigger
    get "/events", EventsController, :subscribe

    get "/home", HomeController, :index

    get "/profile", ProfileController, :show
    get "/achievements/locked", AchievementsController, :locked
    get "/achievements", AchievementsController, :index
    get "/games/platforms", GamesController, :platforms
    get "/games/:platform/:external_id/achievements", GamesController, :achievements
    get "/games", GamesController, :index

    get "/friends/leaderboard", FriendsController, :leaderboard
    get "/friends/pending", FriendsController, :pending
    get "/friends/:user_id/compare", FriendsController, :compare
    resources "/friends", FriendsController, only: [:index, :create, :delete]
    put "/friends/:id/accept", FriendsController, :accept

    patch "/me/favorite-game", ProfileCustomizationController, :set_favorite_game
    put "/me/showcase/games", ProfileCustomizationController, :set_game_showcase
    put "/me/showcase/achievements", ProfileCustomizationController, :set_achievement_showcase
  end
end
