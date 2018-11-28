defmodule Guss.Resource do
  @moduledoc """
  Data structure for Signed URL components.
  """

  @typedoc """
  Predefined (canned) access control policies.

  For more information, see [ACL Header](https://cloud.google.com/storage/docs/xml-api/reference-headers#xgoogacl).
  """
  @type acl_policy() ::
          :private
          | :project_private
          | :public_read
          | :public_read_write
          | :authenticated_read
          | :bucket_owner_read
          | :bucket_owner_full_control
          | String.t()

  @typedoc "HTTP verbs for Signed URLs."
  @type http_verb() :: :get | :post | :put | :delete

  @typedoc """
  Canonical extension headers provide extended request functionality.

  For more information, see [Canonical Extension Headers](https://cloud.google.com/storage/docs/access-control/signed-urls#about-canonical-extension-headers).
  """
  @type extensions() :: [extension_header()]

  @type extension_header() :: [
          acl_header()
          | meta_header()
          | {atom() | String.t(), atom() | String.t()}
        ]

  @type acl_header() :: {:acl, acl_policy()}

  @typedoc """
  Custom metadata for resource requests/responses.

  For more information, see [Custom Metadata Headers](https://cloud.google.com/storage/docs/xml-api/reference-headers#xgoogmeta)
  """
  @type meta_header() :: {:meta, list()}

  @typedoc """
  Components of a GCS Resource URL

  For more information, see [String Components](https://cloud.google.com/storage/docs/access-control/signed-urls#string-components).
  """
  @enforce_keys [:bucket, :objectname]
  @type t() :: %__MODULE__{
          account: nil | atom() | String.t(),
          base_url: String.t(),
          bucket: String.t(),
          content_md5: nil | String.t(),
          content_type: nil | String.t(),
          expires: nil | non_neg_integer(),
          extensions: extensions(),
          http_verb: http_verb(),
          objectname: String.t()
        }

  defstruct account: :default,
            base_url: "https://storage.googleapis.com",
            bucket: nil,
            content_md5: nil,
            content_type: nil,
            expires: nil,
            extensions: [],
            http_verb: :get,
            objectname: nil

  defimpl List.Chars do
    import Guss.Canonical

    def to_charlist(resource) do
      for component <- [:http_verb, :content_md5, :content_type, :expires, :extensions, :resource] do
        canonicalise(resource, component)
      end
      |> Enum.reject(&is_nil/1)
    end
  end

  defimpl String.Chars do
    import Guss.Canonical

    def to_string(resource) do
      Enum.join([resource.base_url, canonicalise(resource, :resource)])
    end
  end
end
