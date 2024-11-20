defmodule ElBot.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      consolidate_protocols: Mix.env() == :prod,
      preferred_cli_env: [
        "test.unit": :test,
        "test.integration": :integration
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end

  defp aliases do
    [
      setup: [
        "ecto.drop",
        "ecto.create",
        "ecto.migrate",
        "run apps/streamer/priv/seed_settings.exs",
        "run apps/naive/priv/seed_settings.exs"
      ],
      "test.integration": [
        "setup",
        "do --app naive test --only integration"
      ],
      "test.unit": [
        "do --app naive test --only unit --no-start"
      ]
    ]
  end
end
