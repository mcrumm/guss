defmodule Guss.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :guss,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Generate Signed URLs for Google Cloud Storage",
      package: package(),
      source_url: github_link(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: [
        "Michael Crumm"
      ],
      licenses: ["MIT"],
      links: %{
        "GitHub" => github_link(),
        "GCS Signed URLs" => "https://cloud.google.com/storage/docs/access-control/signed-urls"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: github_link(),
      groups_for_modules: [
        "request components": [
          Guss.Resource,
          Guss.RequestHeaders
        ],
        signatures: [
          Guss.StorageV2Signer,
          Guss.Signature
        ]
      ]
    ]
  end

  defp github_link, do: "https://github.com/ReelCoaches/guss"

  defp deps do
    [
      {:goth, "~> 0.11.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:junit_formatter, "~> 2.1", only: :test}
    ]
  end
end
