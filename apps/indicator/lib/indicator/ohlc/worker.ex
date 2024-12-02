defmodule Indicator.Ohlc.Worker do
  use GenServer

  alias Core.TradeEvent

  require Logger

  def start_link(symbol) do
    GenServer.start_link(__MODULE__, symbol)
  end

  def init(symbol) do
    symbol = String.upcase(symbol)

    Logger.info(" Initializing new OHLC worker for #{symbol}")

    Phoenix.PubSub.subscribe(
      Core.PubSub,
      "TRADE_EVENTS:#{symbol}"
    )

    {:ok, symbol}
  end

  def handle_info(%TradeEvent{} = trade_event, ohlc) do
    {:noreply, Indicator.Ohlc.process(ohlc, trade_event)}
  end
end
