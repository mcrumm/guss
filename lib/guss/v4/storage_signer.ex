defmodule Guss.V4.StorageSigner do

  @moduledoc """
  There are lots of ambiguities [in the docs](https://cloud.google.com/storage/docs/access-control/signing-urls-manually) on how to roll onc's own solution.

  + Step  2 of  the algorithm  ("_Use a  SHA-256 hashing
    function  to  create  a hex-encoded  hash  value  of
    the  canonical request._")  does  not  say that  hex
    characters  need  to  be  in  lower  case.  This  is
    an  issue, because  `Base.encode16` creates  a valid
    hex-string, but it is  in upper-case by default, and
    the signing will fail.

  + Step 5  of the algorithm  does not mention  that the
    signed string should be hex-encoded.

  + **Percent encoding**  

    [Canonical requests](https://cloud.google.com/storage/docs/authentication/canonical-requests)
    mentions  percent encoding  in  the "Resource  path"
    section, but  nothing when going into  the canonical
    query string  (even though  it needs  encoding). The
    above guide and  [the Python reference implementation](https://cloud.google.com/storage/docs/access-control/signing-urls-manually#python-sample)
    also contradicts how `gsutil signUrl` works:

    - The alleged reserved characters are ?=!#$&'()*+,:;@[].",
      but the Python  code uses [`six.moves.urllib.quote()`](https://docs.python.org/2/library/urllib.html#urllib.quote)
      which  states   that  "_Letters,  digits,   and  the
      characters '_.-'  are never quoted_". So  the period
      (`.`)  is already  off  the list  which makes  sense
      because there are file extensions to consider.

    - The Python  code percent  encodes the  entire object
      name,  even `/`  (`quote(str,  safe='')`), and  that
      quoted value  will get  appended to the  signed URL.
      `gsutil`  does not  encode the  slashes, and  appear
      normal. So in this case, the reserved characters are
      actually telling the truth.
  """

  alias __MODULE__

  # TODO add POST
  # Omitting it for now; it can only be used with
  # resumable uploads anyway (see issue #6 and
  # https://cloud.google.com/storage/docs/authentication/canonical-requests#verbs )
  @http_verbs ~w(DELETE GET HEAD PUT)

  @reservered_chars '?=!#$&\'()*+,:;@[]"'
  @signing_algorithm  "GOOG4-RSA-SHA256"
  @hostname  "storage.googleapis.com"

  @doc """
  Notes on Google Cloud Storage's [Canonical requests](https://cloud.google.com/storage/docs/authentication/canonical-requests) document:

  + `bucket`  and  `object_name`  are expected  to  be
    taken from the output of
    `GoogleApi.Storage.V1.Api.Objects.storage_objects_list/2`,
    such as:

    ```elixir
    {:ok,
    [
      %GoogleApi.Storage.V1.Model.Object{
        acl: nil,
        bucket: "my-bucket",
        cacheControl: nil,
        componentCount: nil,
        contentDisposition: nil,
        contentEncoding: nil,
        contentLanguage: nil,
        contentType: "audio/mpeg",
        crc32c: "dOFRMg==",
        customerEncryption: nil,
        etag: "CNKSuu3rj+QCEAE=",
        eventBasedHold: nil,
        generation: "1566248906164562",
        id: "my-bucket/throw-me-an-anchor.mp3/1566248906164562",
        kind: "storage#object",
        kmsKeyName: nil,
        md5Hash: "XPJP4Lp5I/8l6tGvGAlsGA==",
        mediaLink: "https://www.googleapis.com/download/storage/v1/b/my-bucket/o/throw-me-an-anchor.mp
    3?generation=1566248906164562&alt=media",
        metadata: nil,
        metageneration: "1",
        name: "throw-me-an-anchor.mp3",
        owner: nil,
        retentionExpirationTime: nil,
        selfLink: "https://www.googleapis.com/storage/v1/b/my-bucket/o/throw-me-an-anchor.mp3",
        size: "9945957",
        storageClass: "MULTI_REGIONAL",
        temporaryHold: nil,
        timeCreated: ~U[2019-08-19 21:08:26.164Z],
        timeDeleted: nil,
        timeStorageClassUpdated: ~U[2019-08-19 21:08:26.164Z],
        updated: ~U[2019-08-19 21:08:26.164Z]
      }
    ]}
    ```

    See the [`google_api_storage`](https://hexdocs.pm/google_api_storage/api-reference.html) documentation for more. (Usage example [here](https://github.com/access-news/volunteers/blob/ef382d6f33e6bda21ef219ed35f64e0c76893157/lib/anv/storage.ex).)

  + The `PAYLOAD` is  simply `UNSIGNED-PAYLOAD`, because
    I  don't know  of  a  use case  that  would use  the
    `Authorization` header yet. See
    https://cloud.google.com/storage/docs/authentication/canonical-requests#payload
    for more.
  """
  # input =
  #   %{
  #     http_verb:     verb in @http_verbs,
  #
  #     --  PATH_TO_RESOURCE  ---
  #     bucket:        String.t(),      # %GoogleApi.Storage.V1.Model.Object.bucket
  #     object_name:   String.t(),      # %GoogleApi.Storage.V1.Model.Object.name
  #
  #                               ---param--     --value--
  #     query_params:  %{optional(String.t()) => String.t(),

  #                               --header--     --value--
  #     headers:       %{optional(String.t()) => String.t(),

  #     expires:       integer() | {n, interval},      # see to_seconds/2
  #   }
  def signed_url(%{ bucket: bucket, object_name: object_name } = input) do

    current_datetime = now_iso8601_basic()

    path_to_resource =
      "/" <> bucket <> "/" <> object_name

    { canonical_headers, signed_headers } =
      input[:headers]
      |> canonicalize_headers_and_produce_signed_headers()

    canonical_query_string =
      canonicalize_query_params(
        input[:query_params],
        expires_in(input[:expires]),
        signed_headers,
        current_datetime
      )

    http_verb =
      input[:http_verb]
      |> parse_http_verb()

    canonical_request =
      Enum.join([
        http_verb,              "\n",
        path_to_resource,       "\n",
        canonical_query_string, "\n",
        canonical_headers,      "\n\n",
        signed_headers,         "\n",
        "UNSIGNED-PAYLOAD"      # see note in function doc
      ])

    hashed_canonical_request =
      canonical_request
      |> (&:crypto.hash(:sha256, &1)).()
      |> Base.encode16()
      |> String.downcase() # just for good measure

    string_to_sign =
      [
        @signing_algorithm,
        current_datetime,
        credential_scope(current_datetime),
        hashed_canonical_request,
      ]
      |> Enum.join("\n")

    request_signature =
      string_to_sign
      |> sign()
      |> Base.encode16()
      |> String.downcase()

    "https://" <> @hostname <>
      path_to_resource <> "?" <>
      canonical_query_string <> "&X-Goog-Signature=" <>
      request_signature
  end

  defp sign(string_to_sign) do
    private_key =
      Goth.Config.get("private_key")
      |> elem(1)
      |> decode_key!()

    :public_key.sign(string_to_sign, :sha256, private_key)
  end

  # Decodes a GCS Service Account private key for URL signing.
  #
  # For more information, see this comment on `erlang-jose`:
  # https://github.com/potatosalad/erlang-jose/issues/13#issuecomment-160718744
  defp decode_key!(private_key) do
    private_key
    |> :public_key.pem_decode()
    |> hd()
    |> :public_key.pem_entry_decode()
  end

  defp parse_http_verb(nil), do: "GET"
  defp parse_http_verb(verb) when not(is_binary(verb)),
    do: raise ArgumentError, "HTTP verb must be a string, such as \"GET\""

  defp parse_http_verb(verb) do
    upcase_verb = String.upcase(verb)

    case upcase_verb in @http_verbs do
      true ->
        upcase_verb
      false ->
        raise(
          ArgumentError,
          "\"#{verb}\" not supported. Please choose one from #{Enum.join(@http_verb, ",")}"
        )
    end
  end

  def expires_in({n, granularity}) when is_integer(n) and n > 0 do
    expires_in(to_seconds(n, granularity))
  end

  def expires_in(nil), do: 3600

  def expires_in(seconds) when is_integer(seconds) do
    case seconds > 604800 do
      true ->
        raise ArgumentError, "Expiration Time can't be longer than 604800 seconds (7 days)."
      false ->
        seconds
    end
  end

  defp to_seconds(n, i) when i in [:second, :seconds], do: n
  defp to_seconds(n, i) when i in [:minute, :minutes], do: n * 60
  defp to_seconds(n, i) when i in [:hour, :hours], do: n * 3600
  defp to_seconds(n, i) when i in [:day, :days], do: n * 3600 * 24

  @doc """
  From [Canonical Query strings](https://cloud.google.com/storage/docs/authentication/canonical-requests#about-query-strings):

  > Canonical   requests   include  any   query   string
  > parameters  that must  be  subsequently included  in
  > signed  requests that  use  the relevant  signature.
  > However, such signed requests may include additional
  > query string  parameters that were not  specified in
  > the canonical request. The query string specified in
  > the canonical request is  called the canonical query
  > string.

  The way I  interpret this: if one signs  an URI that
  has query strings, those will have to be included in
  the signed URL as well (as  they will be part of the
  signature), but additional  query strings can always
  be added.

  On  top   of  that,  the  following   query  strings
  parameters are **always** required (in the canonical
  request  for the  signature, and  in the  signed URL
  when it is constructed):

  + `X-Goog-Algorithm`
  + `X-Goog-Credential`
  + `X-Goog-Date`
  + `X-Goog-Expires`
  + `X-Goog-SignedHeaders`
  + `X-Goog-Signature`
  """
  defp canonicalize_query_params( nil, expires, signed_headers, current_datetime),
    do: canonicalize_query_params(%{}, expires, signed_headers, current_datetime)

  defp canonicalize_query_params(query_params, expires, signed_headers, current_datetime) do
    query_params
    |> add_required_query_params(expires, signed_headers, current_datetime)
    |> Enum.sort()
    |> Enum.reduce(
         [],
         fn { param, value }, acc ->

           [ encoded_param, encoded_value ] =
             Enum.map(
               [param, value],
               &(&1 |> to_string() |> URI.encode_www_form())
             )

           [ Enum.join([encoded_param, encoded_value], "=") | acc ]
         end
       )
    |> Enum.reverse()
    |> Enum.join("&")
  end

  @doc """
  `gsutil` generates the required params in lowercase,
  but the  docs don't specify  that they must  be. The
  sample Python implementation
  (https://cloud.google.com/storage/docs/access-control/signing-urls-manually#python-sample)
  also doesn't mess with their original form.
  """
  defp add_required_query_params(query_params_map, expires, signed_headers, current_datetime) do

    credential =
      get_authorizer() <> "/" <> credential_scope(current_datetime)

    %{
      "X-Goog-Algorithm"     => @signing_algorithm,
      "X-Goog-Credential"    => credential,
      "X-Goog-Date"          => current_datetime,
      "X-Goog-Expires"       => expires, # in seconds, user provided
      "X-Goog-SignedHeaders" => signed_headers, # user provided: headers
    }
    |> Map.merge(query_params_map)
  end

  def get_authorizer() do
    # TODO: make it Goth-independent, just like the rest of Guss
    Goth.Config.get("client_email") |> elem(1)
  end

  # https://cloud.google.com/storage/docs/access-control/signed-urls#credential-scope
  defp credential_scope(current_datetime) do
    [
      #   [DATE]
      current_datetime |> String.slice(0..7),
      #   [LOCATION]
      #   > The  region where  the resource  resides or  will be
      #   > created. For  Cloud Storage resources, the  value of
      #   > [LOCATION]  is arbitrary:  the [LOCATION]  parameter
      #   > exists to maintain  compatibility with Amazon Simple
      #   > Storage Service (Amazon S3).
      # TODO: make it a user input eventually
      "us",
      "storage",
      "goog4_request"
    ]
    |> Enum.join("/")
  end

  @doc """
  From [Canonical Headers](https://cloud.google.com/storage/docs/authentication/canonical-requests#about-headers):

  > Canonical  requests include  any  headers that  must
  > be  subsequently included  in  signed requests  that
  > use  the relevant  signature.  However, such  signed
  > requests  may include  additional headers  that were
  > not specified  in the  canonical request,  except as
  > noted in required headers.  Headers specified in the
  > canonical request are called canonical headers

  Assuming     the      same     as      stated     in
  `construct_canonical_query/1`   plus  the   required
  `host` header:

  ```text
  host:storage.googleapis.com
  ```

  ## Duplicate headers

  > Eliminate  duplicate header  names  by creating  one
  > header name  with a comma-separated list  of values.
  > Be sure  there is no whitespace  between the values,
  > and be  sure that  the order of  the comma-separated
  > list matches  the order  that the headers  appear in
  > your request.

  Headers are supplied as maps therefore any duplicate
  header will be overwritten  with the last occurence.
  If one wants to have  a header take multiple values,
  construct a comma-separated  value as the "Canonical
  Headers" document suggests.
  """
  defp canonicalize_headers_and_produce_signed_headers(nil),
    do: canonicalize_headers_and_produce_signed_headers(%{})

  defp canonicalize_headers_and_produce_signed_headers(headers) do

    { canonicalized_headers_list, signed_headers_list } =
        headers
        |> add_required_headers()
        |> Enum.sort()
        |> Enum.reduce(
            { [], [] },
            fn
              { header, value },
              { ch_list, sh_list } # acc
            ->
              downcased_header = String.downcase(header)
              whitespace_folded_value = String.replace(value, ~r/\s+/, " ")

              new_header_line =
                downcased_header <> ":" <> whitespace_folded_value

              {
                [ new_header_line  | ch_list ],
                [ downcased_header | sh_list ]
              }
            end
          )

    {
      canonicalized_headers_list |> Enum.reverse() |> Enum.join("\n"),
      signed_headers_list        |> Enum.reverse() |> Enum.join(";")
    }
  end

  defp add_required_headers(headers) do
    Map.put(headers, "host", @hostname)
  end

  def now_iso8601_basic() do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
  end
end
