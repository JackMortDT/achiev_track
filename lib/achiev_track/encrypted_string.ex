defmodule AchievTrack.EncryptedString do
  @moduledoc """
  Custom Ecto type that transparently encrypts on write and decrypts on read.
  """
  use Ecto.Type

  def type, do: :string

  # cast: accept plaintext values from user input — store in memory as plaintext
  def cast(nil), do: {:ok, nil}
  def cast(val) when is_binary(val), do: {:ok, val}
  def cast(_), do: :error

  # load: decrypt when reading from DB
  def load(nil), do: {:ok, nil}
  def load(val) when is_binary(val) do
    case AchievTrack.Crypto.decrypt(val) do
      {:ok, plaintext} -> {:ok, plaintext}
      :error -> :error
    end
  end
  def load(_), do: :error

  # dump: encrypt when writing to DB
  def dump(nil), do: {:ok, nil}
  def dump(val) when is_binary(val) do
    case AchievTrack.Crypto.encrypt(val) do
      {:ok, encrypted} -> {:ok, encrypted}
      _ -> :error
    end
  end
  def dump(_), do: :error
end
