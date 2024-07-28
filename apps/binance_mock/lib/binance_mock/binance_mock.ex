defmodule BinanceMock do
  use GenServer

  alias Decimal, as: D
  alias Streamer.Binance.TradeEvent

  require Logger

  defmodule State do
    defstruct orderbooks: %{}, subscriptions: [], fake_order_id: 1
  end

  defmodule OrderBook do
    defstruct buy_side: [], sell_size: [], historical: []
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(args) do
    {:ok, %State{}}
  end
end
