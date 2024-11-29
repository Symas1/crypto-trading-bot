require Logger

alias Streamer.Repo
alias Streamer.Schema.Settings

exchange_client = Application.compile_env(:streamer, :exchange_client)

Logger.info("[streamer] Fetching exchange info from Binance")

{:ok, symbols} = exchange_client.fetch_symbols()

timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

base_settings = %{
  symbol: "",
  status: :off,
  inserted_at: timestamp,
  updated_at: timestamp
}

Logger.info("[streamer] Inserting settings")

settings = symbols |> Enum.map(&(%{base_settings | symbol: &1}))

{count, nil} = Repo.insert_all(Settings, settings)

Logger.info("[streamer] Inserted #{count} settings")
