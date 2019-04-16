defmodule Guss do
  @moduledoc """
  Guss generates Signed URLs for Google Cloud Storage.

  Signed URLs provide a mechanism for query-string authentication for storage objects.
  For more information, see the Storage Docs for [Signed URLs](https://cloud.google.com/storage/docs/access-control/signed-urls).
  """

  alias __MODULE__
  alias Guss.Resource

  @base_attrs [:account, :base_url, :content_type, :content_md5, :expires, :http_verb]

  @doc """
  Returns a new `Guss.Resource` for a `GET` request.
  """
  @spec get(binary(), binary(), keyword()) :: Guss.Resource.t()
  def get(bucket, objectname, opts \\ []) do
    new(:get, bucket, objectname, opts)
  end

  @doc """
  Returns a new `Guss.Resource` for a `POST` request.
  """
  def post(bucket, objectname, opts \\ []) do
    new(:post, bucket, objectname, opts)
  end

  @doc """
  Returns a new `Guss.Resource` for a `PUT` request.
  """
  @spec put(binary(), binary(), keyword()) :: Guss.Resource.t()
  def put(bucket, objectname, opts \\ []) do
    new(:put, bucket, objectname, opts)
  end

  @doc """
  Returns a new `Guss.Resource` for a `DELETE` request.
  """
  @spec delete(binary(), binary(), keyword()) :: Guss.Resource.t()
  def delete(bucket, objectname, opts \\ []) do
    new(:delete, bucket, objectname, opts)
  end

  @doc """
  Returns a new `Guss.Resource`.
  """
  @spec new(binary(), binary(), keyword()) :: Guss.Resource.t()
  def new(bucket, objectname, opts \\ []) do
    {attrs, extensions} = Keyword.split(opts, @base_attrs)

    %Resource{bucket: bucket, objectname: objectname}
    |> struct!(Keyword.put(attrs, :extensions, extensions))
  end

  @doc """
  Returns a new `Guss.Resource`.
  """
  @spec new(atom(), binary(), binary(), keyword()) :: Guss.Resource.t()
  def new(verb, bucket, objectname, opts) when is_atom(verb) do
    new(bucket, objectname, Keyword.put(opts, :http_verb, verb))
  end

  @doc """
  Converts a `Guss.Resource` into a Signed URL.
  """
  @spec sign(resource :: Guss.Resource.t(), opts :: keyword()) ::
          {:error, {atom(), any()}} | {:ok, binary()}
  def sign(resource, opts \\ [])

  def sign(%Resource{expires: nil} = resource, opts) do
    sign(%{resource | expires: expires_in(3600)}, opts)
  end

  def sign(%Resource{} = resource, opts) do
    config_mod = Keyword.get(opts, :config_module, Goth.Config)

    with {:ok, {access_id, private_key}} <- Guss.Config.for_resource(config_mod, resource) do
      resource = %{resource | account: access_id}

      Guss.StorageV2Signer.sign(resource, private_key)
    end
  end

  @doc """
  Returns an expiration value for a future timestamp, with optional granularity.

  By default, `expires_in/1` expects a value in `:seconds`.

  To specify a different granularity, pass the value as a tuple,
  for instance: `{1, :hour}` or `{7, :days}`

  Valid granularities are `:seconds, :hours, and :days`, as well as
  their singular variants.
  """
  def expires_in({n, granularity}) when is_integer(n) and n > 0 do
    expires_in(to_seconds(n, granularity))
  end

  def expires_in(seconds) when is_integer(seconds) do
    DateTime.utc_now() |> DateTime.to_unix() |> Kernel.+(seconds)
  end

  defp to_seconds(n, i) when i in [:second, :seconds], do: n
  defp to_seconds(n, i) when i in [:hour, :hours], do: n * 3600
  defp to_seconds(n, i) when i in [:day, :days], do: n * 3600 * 24
end
