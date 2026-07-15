defmodule AchievTrack.Mailer do
  use Swoosh.Mailer, otp_app: :achiev_track

  import Swoosh.Email

  def send_verification_email(user, token) do
    base_url = Application.get_env(:achiev_track, :frontend_url, "http://localhost:3000")
    link = "#{base_url}/verificar-email?token=#{token}"
    from_email = Application.get_env(:achiev_track, :mail_from, "noreply@retroplatform.local")
    from_name = Application.get_env(:achiev_track, :mail_from_name, "RetroPlatform")

    new()
    |> to({user.username, user.email})
    |> from({from_name, from_email})
    |> subject("Verifica tu email — RetroPlatform")
    |> text_body("""
    Hola #{user.username},

    Verifica tu dirección de email haciendo click en el siguiente enlace:

    #{link}

    El enlace expira en 24 horas. Si no creaste esta cuenta, ignora este mensaje.
    """)
    |> deliver()
  end
end
