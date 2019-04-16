defmodule Guss.StorageV2Signer do
  @moduledoc """
  Signs a `Guss.Resource` using the V2 Signing Process.
  """
  alias Guss.Signature

  @doc """
  Sign a URL for the given `Guss.Resource` using the `private_key`.
  """
  @spec sign(resource :: Guss.Resource.t(), private_key :: binary()) :: {:ok, String.t()}
  def sign(%Guss.Resource{} = resource, private_key) when is_binary(private_key) do
    with {:ok, signature} <- Signature.generate(resource, private_key) do
      signed_url = build_url(resource, signature)
      {:ok, signed_url}
    end
  end

  @spec build_url(Guss.Resource.t(), binary()) :: String.t()
  def build_url(%Guss.Resource{} = resource, signature) when is_binary(signature) do
    query = resource |> build_signed_query(signature) |> URI.encode_query()

    Enum.join([to_string(resource), "?", query])
  end

  defp build_signed_query(%Guss.Resource{account: account, expires: expires}, signature) do
    %{
      "GoogleAccessId" => account,
      "Expires" => expires,
      "Signature" => signature
    }
  end
end
