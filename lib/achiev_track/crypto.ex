defmodule AchievTrack.Crypto do
  @moduledoc """
  AES-256-GCM encryption for sensitive fields like API keys.
  Derives the encryption key from the application's secret_key_base.
  """

  defp encryption_key do
    secret = Application.fetch_env!(:achiev_track, AchievTrackWeb.Endpoint)[:secret_key_base]
    :crypto.hash(:sha256, secret)
  end

  def encrypt(nil), do: {:ok, nil}
  def encrypt(plaintext) when is_binary(plaintext) do
    iv = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, encryption_key(), iv, plaintext, "", true)
    {:ok, Base.encode64(iv <> tag <> ciphertext)}
  end

  def decrypt(nil), do: {:ok, nil}
  def decrypt(encoded) when is_binary(encoded) do
    with {:ok, data} <- Base.decode64(encoded),
         <<iv::binary-12, tag::binary-16, ciphertext::binary>> <- data do
      case :crypto.crypto_one_time_aead(:aes_256_gcm, encryption_key(), iv, ciphertext, "", tag, false) do
        plaintext when is_binary(plaintext) -> {:ok, plaintext}
        _ -> :error
      end
    else
      _ ->
        # Not encrypted (legacy plaintext) — return as-is
        {:ok, encoded}
    end
  end
end
