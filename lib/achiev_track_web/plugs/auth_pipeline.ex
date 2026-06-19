defmodule AchievTrackWeb.Plugs.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :achiev_track,
    module: AchievTrack.Auth.Guardian,
    error_handler: AchievTrackWeb.Plugs.AuthErrorHandler

  plug AchievTrackWeb.Plugs.CookieToToken
  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource, allow_blank: false
end
