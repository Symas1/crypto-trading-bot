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
alias Hedgehog.Streamer.Settings

binance_client = Application.compile_env(:hedgehog, :binance_client)

Logger.info("[streamer] Fetching exchange info from Binance")

{:ok, %{symbols: symbols}} = binance_client.get_exchange_info()

timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

base_settings = %{
  symbol: "",
  status: :off,
  inserted_at: timestamp,
  updated_at: timestamp
}

Logger.info("[streamer] Inserting settings")

settings = symbols |> Enum.map(&%{base_settings | symbol: &1["symbol"]})

{count, nil} = Repo.insert_all(Settings, settings)

Logger.info("[streamer] Inserted #{count} settings")
