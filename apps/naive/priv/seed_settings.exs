require Logger

alias Naive.Repo
alias Naive.Schema.Settings

exchange_client = Application.compile_env(:naive, :exchange_client)

Logger.info("[naive] Fetching exchange info from Binance")

{:ok, symbols} = exchange_client.fetch_symbols()

%{
  chunks: chunks,
  budget: budget,
  buy_down_interval: buy_down_interval,
  profit_interval: profit_interval,
  rebuy_interval: rebuy_interval
} = Application.compile_env(:naive, :trading).defaults

timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

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

Logger.info("[naive] Inserting default settings for symbols")

maps = symbols |> Enum.map(&(%{base_settings | symbol: &1}))

{count, nil} = Repo.insert_all(Settings, maps)

Logger.info("[naive] Inserted settings for #{count} symbols")
