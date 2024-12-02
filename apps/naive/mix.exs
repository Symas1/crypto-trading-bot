defmodule Naive.MixProject do
  use Mix.Project

  def project do
    [
      app: :naive,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Naive.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:binance, "~> 1.0"},
      {:decimal, "~> 2.0"},
      {:ecto_sqlite3, "~> 0.17"},
      {:phoenix_pubsub, "~> 2.0"},
      {:core, in_umbrella: true},
      {:binance_mock, in_umbrella: true},
      {:data_warehouse, in_umbrella: true, only: :test},
      {:mimic, "~> 1.10", only: [:test, :integration]}
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
