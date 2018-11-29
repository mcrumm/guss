defmodule Guss.Signature do
  @moduledoc """
  Signs resources using RSA signatures with SHA256 to authenticate requests.

  Signature was built to work with a `Guss.Resource`, but it will accept
  any struct that implements `List.Chars`.

  For more information, see [Creating a Signed URL using a program](https://cloud.google.com/storage/docs/access-control/create-signed-urls-program).
  """
  @otp_greater_21? :erlang.system_info(:otp_release) >= '21'

  @doc """
  Signs the resource iodata using a service account key.

  The given resource must implement the `List.Chars` protocol.
  """
  @spec generate(any(), binary()) :: {:error, {:signature, any()}} | {:ok, binary()}
  def generate(resource, private_key) when is_binary(private_key) do
    try do
      signature = generate!(resource, private_key)

      {:ok, signature}
    rescue
      e -> {:error, {:signature, e}}
    end
  end

  @doc """
  Signs the resource iodata using a service account key.

  Same as `generate/2`, but raises on error.
  """
  @spec generate!(any(), binary()) :: binary()
  def generate!(resource, private_key) when is_binary(private_key) do
    decoded_key = decode_key!(private_key)

    resource
    |> to_charlist()
    |> to_string()
    |> :public_key.sign(:sha256, decoded_key)
    |> Base.encode64()
  end

  # Decodes a GCS Serive Account private key for URL signing.
  #
  # For more information, see this comment on `erlang-jose`:
  # https://github.com/potatosalad/erlang-jose/issues/13#issuecomment-160718744
  defp decode_key!(private_key) do
    private_key
    |> :public_key.pem_decode()
    |> (fn [x] -> x end).()
    |> :public_key.pem_entry_decode()
    |> normalize_key!()
  end

  # Prior to OTP 21, service account keys required additional decoding.
  defp normalize_key!(private_key) do
    if @otp_greater_21? do
      private_key
    else
      private_key
      |> elem(3)
      |> (fn pk -> :public_key.der_decode(:RSAPrivateKey, pk) end).()
    end
  end
end
