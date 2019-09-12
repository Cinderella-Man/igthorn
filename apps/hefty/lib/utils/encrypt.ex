defmodule Hefty.Utils.Encrypt do
  alias Encrypt, as: E

  def encrypt(val, secret) do
   E.encrypt(val, secret)
    |> :base64.encode
  end

  def decrypt(ciphertext, key) do
    E.decrypt(ciphertext, key)
  end
end