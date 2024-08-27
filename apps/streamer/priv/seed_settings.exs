require Logger

alias Streamer.Repo
alias Streamer.Schema.Settings

Logger.info("Fetching exchange info from Binance")

{:ok, %{symbols: symbols}} = Binance.get_exchange_info()

timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

base_settings = %{
  symbol: "",
  status: :off,
  inserted_at: timestamp,
  updated_at: timestamp
}

Logger.info("Inserting settings")

settings = symbols |> Enum.map(&(%{base_settings | symbol: &1["symbol"]}))

{count, nil} = Repo.insert_all(Settings, settings)

Logger.info("Inserted #{count} settings")
