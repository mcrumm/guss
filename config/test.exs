use Mix.Config

config :goth,
  json: "config/test-credentials.json" |> Path.expand() |> File.read!()

config :junit_formatter,
  report_dir: "_build/test/lib/guss/exunit"
