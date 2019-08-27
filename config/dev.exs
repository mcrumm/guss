use Mix.Config

try do
  config :goth,
  json: "config/test-credentials.json" |> Path.expand() |> File.read!()
rescue
  _ ->
    config :goth, json: "{}"
end
