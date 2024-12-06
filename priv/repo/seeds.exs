# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Hedgehog.Repo.insert!(%Hedgehog.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

require Logger

alias Hedgehog.Repo
alias Hedgehog.Streamer.Settings, as: StreamerSettings
alias Hedgehog.Strategy.Naive.Settings, as: NaiveStrategySettings

binance_client = Application.compile_env(:hedgehog, :binance_client)

Logger.info("Fetching exchange info from Binance")
{:ok, %{symbols: symbols}} = binance_client.get_exchange_info()

timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

# Streamer
base_settings = %{
  symbol: "",
  status: :off,
  inserted_at: timestamp,
  updated_at: timestamp
}

Logger.info("[streamer] Inserting settings")

settings = symbols |> Enum.map(&%{base_settings | symbol: &1["symbol"]})

{count, nil} = Repo.insert_all(StreamerSettings, settings)

Logger.info("[streamer] Inserted #{count} settings")
# ~Streamer

# Naive
%{
  chunks: chunks,
  budget: budget,
  buy_down_interval: buy_down_interval,
  profit_interval: profit_interval,
  rebuy_interval: rebuy_interval
} = Application.compile_env(:hedgehog, [:strategy, :naive, :defaults])

base_settings = %{
  symbol: "",
  chunks: chunks,
  budget: Decimal.new(budget),
  buy_down_interval: Decimal.new(buy_down_interval),
  profit_interval: Decimal.new(profit_interval),
  rebuy_interval: Decimal.new(rebuy_interval),
  status: :off,
  inserted_at: timestamp,
  updated_at: timestamp
}

Logger.info("[naive strategy] Inserting default settings for symbols")

maps = symbols |> Enum.map(&%{base_settings | symbol: &1["symbol"]})

{count, nil} = Repo.insert_all(NaiveStrategySettings, maps)

Logger.info("[naive strategy] Inserted settings for #{count} symbols")
# ~Naive
