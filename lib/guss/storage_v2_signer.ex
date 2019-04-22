defmodule Guss.StorageV2Signer do
  @moduledoc """
  Sign a `Guss.Resource` using the Cloud Storage V2 Signing Process for Service Accounts.

  This module generates the _string to sign_ for a ` Guss.Resource`,
  and signs it using the given `private_key`. The signature is then
  added to the URL, along with any required query string parameters.

  For more information, see:
  [V2 Signing Process](https://cloud.google.com/storage/docs/access-control/signed-urls-v2).
  """
  alias Guss.{Resource, RequestHeaders, Signature}

  @doc """
  Sign a URL for the given `Guss.Resource` using the `private_key`.
  """
  @spec sign(resource :: Guss.Resource.t(), private_key :: binary()) :: {:ok, String.t()}
  def sign(%Resource{} = resource, private_key) when is_binary(private_key) do
    s2s = string_to_sign(resource)

    with {:ok, signature} <- Signature.generate(s2s, private_key) do
      signed_url = build_url(resource, signature)
      {:ok, signed_url}
    end
  end

  @doc """
  Generates the _string to sign_ for a `Guss.Resource`.

  The _string to sign_ is a canonical representation of
  the request to be made with the Signed URL.
  """
  @spec string_to_sign(Guss.Resource.t()) :: String.t()
  def string_to_sign(%Resource{} = resource) do
    headers_to_sign =
      resource
      |> Resource.signed_headers()
      |> headers_to_sign()

    http_verb = http_verb(resource.http_verb)

    resource_name = resource_name(resource)

    content_md5 = if is_nil(resource.content_md5), do: "", else: resource.content_md5

    content_type = if is_nil(resource.content_type), do: "", else: resource.content_type

    [
      http_verb,
      content_md5,
      content_type,
      Integer.to_string(resource.expires),
      headers_to_sign,
      resource_name
    ]
    |> Enum.intersperse(?\n)
    |> IO.iodata_to_binary()
  end

  defp resource_name(%{bucket: bucket, objectname: objectname}) do
    [?/, bucket, ?/, objectname]
  end

  defp http_verb(method) when is_atom(method), do: http_verb(Atom.to_string(method))
  defp http_verb(method) when is_binary(method), do: String.upcase(method)

  defp headers_to_sign([]), do: []

  defp headers_to_sign(headers) when is_list(headers) do
    for {k, v} <- RequestHeaders.deduplicate(headers),
        filter_extension({k, v}) do
      [k, ?:, v]
    end
    |> Enum.intersperse(?\n)
    |> List.wrap()
  end

  defp filter_extension({"x-goog-encryption" <> _rest, _}), do: false
  defp filter_extension({"x-goog-" <> _rest, _}), do: true
  defp filter_extension(_kv), do: false

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
