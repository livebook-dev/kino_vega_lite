defmodule KinoVegaLite.MixProject do
  use Mix.Project

  @version "0.1.8"
  @description "Vega-Lite integration with Livebook"

  def project do
    [
      app: :kino_vega_lite,
      version: @version,
      description: @description,
      name: "KinoVegaLite",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      mod: {KinoVegaLite.Application, []}
    ]
  end

  defp deps do
    [
      {:kino, "~> 0.7"},
      {:table, "~> 0.1.0"},
      {:vega_lite, "~> 0.1.4"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "components",
      source_url: "https://github.com/livebook-dev/kino_vega_lite",
      source_ref: "v#{@version}",
      extras: ["guides/components.livemd"],
      groups_for_modules: [
        Kinos: [
          Kino.VegaLite
        ]
      ]
    ]
  end

  def package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/livebook-dev/kino_vega_lite"
      }
    ]
  end
end
