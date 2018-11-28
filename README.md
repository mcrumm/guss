# Guss

Generate [Signed URLs](https://cloud.google.com/storage/docs/access-control/signed-url) for Google Cloud Storage in Elixir.

## Installation

  1. Add `guss` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:guss, "~> 0.1.0"}
  ]
end
```

  2. If you're using [Goth](https://github.com/peburrows/goth) for authentication, be sure to configure your credentials:

```elixir
config :goth,
  json: {:system, "GCP_CREDENTIALS_JSON"}
```

## Usage

First, create a new resource with your URL components:

```elixir
iex(1)> url = Guss.new("downloads", "movie.mp4", content_type: "video/mp4")
%Guss.Resource{bucket: "downloads", objectname: "movie.mp4"...}
```

Then, sign the url:

```elixir
iex(2)> Guss.sign(url)
{:ok, "https://storage.googleapis.com/downloads/movie.mp4?Expires=1543..."}
```

### Signatures

By default, `sign/1` will use the default credentials stored in the Goth config to generate the signature.

To specify an account other than the default, update the `:account` on the resource:

```elixir
Guss.sign(%{url | account: "service-account@example.com"})
```

It is also possible to [use Guss without Goth](#usage-without-goth).

### Expiration

The default `:expires` value is 1 hour.  You can use `Guss.expires_in/1` to set a custom future timestamp:

```elixir
iex(4)> url = Guss.new("downloads", "movie.mp4", expires: Guss.expires_in({1, :day}))
%Guss.Resource{
  account: :default,
  base_url: "https://storage.googleapis.com",
  bucket: "downloads",
  content_md5: nil,
  content_type: nil,
  expires: 1543526299,
  extensions: [],
  http_verb: :get,
  objectname: "movie.mp4"
}
```

### Write Requests

Guss can generate URLs for temporary write access to GCS buckets.

#### Custom Extension Headers

TODO: Add docs


## Usage without Goth

If you store your authentication data somewhere other than Goth, you can supply your own config module when signing URLs.

First, create a module that can return values for `"client_email"` and `"private_key"`:

```elixir
defmodule MyGussConfig do
  def get(account \\ :default, key)
  def get(account, "client_email"), do: fetch_email(account)
  def get(account, "private_key"), do: fetch_private_key(account)
end
```

Then, create a resource and sign it using your config module:

```elixir
"bucket"
|> Guss.new("objectname", account: "user@example.com")
|> Guss.sign(config_module: MyGussConfig)
```









Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/guss](https://hexdocs.pm/guss).
