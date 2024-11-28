# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#

config :logger,
  level: :info

config :data_warehouse,
  ecto_repos: [DataWarehouse.Repo]

config :naive,
  ecto_repos: [Naive.Repo],
  repo: Naive.Repo,
  binance_client: BinanceMock,
  trading: %{
    defaults: %{
      chunks: 5,
      budget: 1000,
      buy_down_interval: "0.0001",
      profit_interval: "-0.0012",
      rebuy_interval: "0.001"
    }
  }

config :streamer,
  binance_client: BinanceMock,
  ecto_repos: [Streamer.Repo]

config :data_warehouse, DataWarehouse.Repo, database: "warehouse.db"
config :naive, Naive.Repo, database: "naive.db"
config :streamer, Streamer.Repo, database: "streamer.db"

# Import secrets with Binance keys
if File.exists?("config/secrets.exs") do
  import_config("secrets.exs")
end

config :binance_mock,
  root: File.cwd!(),
  use_cached_exchange_info: false

config :core,
  pubsub_client: Phoenix.PubSub,
  logger: Logger

import_config "#{config_env()}.exs"
