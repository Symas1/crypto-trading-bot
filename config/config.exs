# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :hedgehog,
  binance_client: Hedgehog.Exchange.BinanceMock,
  ecto_repos: [Hedgehog.Repo],
  generators: [timestamp_type: :utc_datetime],
  exchanges: [
    binance_mock: [
      use_cached_exchange_info: true
    ]
  ],
  strategy: [
    naive: [
      defaults: %{
        chunks: 5,
        budget: 1000,
        buy_down_interval: "0.0001",
        profit_interval: "-0.0012",
        rebuy_interval: "0.001"
      }
    ]
  ]

# Configures the endpoint
config :hedgehog, HedgehogWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: HedgehogWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Hedgehog.PubSub,
  live_view: [signing_salt: "rNh6p6eE"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  level: :info

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import secrets with Binance keys
if File.exists?("config/secrets.exs") do
  import_config("secrets.exs")
end

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
