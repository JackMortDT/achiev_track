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
  end
end
