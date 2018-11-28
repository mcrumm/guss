defmodule Guss.MixProject do
  use Mix.Project

  def project do
    [
      app: :guss,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Signs URLs for Google Cloud Storage",
      package: package(),
      name: "Guss",
      source_url: github_link(),
      homepage_url: github_link(),
      docs: [
        main: "Guss",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Michael Crumm"],
      licenses: ["MIT"],
      links: %{"GitHub" => github_link()}
    ]
  end

  defp github_link, do: "https://github.com/ReelCoaches/guss"

  defp deps do
    [
      {:goth, "~> 0.11.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.18.0", only: :dev, runtime: false}
    ]
  end
end
