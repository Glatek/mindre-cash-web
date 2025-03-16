defmodule MindreCash.MixProject do
  use Mix.Project

  def project do
    [
      app: :mindre_cash,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        mindre_cash: [
          include_executables_for: [:unix],
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MindreCash.Application, []}
    ]
  end

  defp deps do
    [
      {:number, "~> 1.0.5"},
      {:plug_cowboy, "~> 2.5"},
      {:httpoison, "~> 1.8"},
      {:jason, "~> 1.2"}
    ]
  end
end
