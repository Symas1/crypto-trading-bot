defmodule Naive.Trader do
  use GenServer, restart: :temporary

  alias Core.TradeEvent

  require Logger

  @pubsub_client Application.compile_env(:core, :pubsub_client)
  @logger Application.compile_env(:core, :logger)

  defmodule State do
    @enforce_keys [
      :id,
      :symbol,
      :buy_down_interval,
      :profit_interval,
      :rebuy_interval,
      :rebuy_notified,
      :tick_size,
      :budget,
      :step_size
    ]
    defstruct [
      :id,
      :symbol,
      :buy_order,
      :sell_order,
      :buy_down_interval,
      :profit_interval,
      :rebuy_interval,
      :rebuy_notified,
      :tick_size,
      :budget,
      :step_size
    ]
  end

  def start_link(%State{} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(%State{id: id, symbol: symbol} = state) do
    symbol = String.upcase(symbol)

    @logger.info("[#{id}] Initializing new trader for #{symbol}")

    @pubsub_client.subscribe(Core.PubSub, "TRADE_EVENTS:#{symbol}")

    {:ok, state}
  end

  def handle_info(%TradeEvent{} = trade_event, %State{} = state) do
    case Naive.Strategy.execute(trade_event, state) do
      {:ok, new_state} -> {:noreply, new_state}
      :exit -> {:stop, :normal, state}
    end
  end
end
