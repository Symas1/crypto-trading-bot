import Config

config :data_warehouse, DataWarehouse.Repo, database: "warehouse_test.db"
config :naive, Naive.Repo, database: "naive_test.db"
config :streamer, Streamer.Repo, database: "streamer_test.db"

config :binance_mock,
  use_cached_exchange_info: true
