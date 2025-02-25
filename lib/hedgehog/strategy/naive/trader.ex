defmodule Hedgehog.Strategy.Naive.Trader do
  use GenServer, restart: :temporary

  alias Hedgehog.Strategy.Naive.Formula
  alias Hedgehog.Exchange.TradeEvent

  require Logger

  @registry :naive_traders

  defmodule State do
    @enforce_keys [:settings, :positions]
    defstruct [:settings, positions: []]
  end

  def start_link(symbol) do
    symbol = String.upcase(symbol)

    GenServer.start_link(__MODULE__, symbol, name: {:via, Registry, {@registry, symbol}})
  end

  def notify(:settings_updated, settings) do
    call_trader(settings.symbol, {:update_settings, settings})
  end

  def get_positions(symbol) do
    call_trader(symbol, {:get_positions, symbol})
  end

  def init(symbol) do
    Logger.info("Initializing new trader for #{symbol}")

    Phoenix.PubSub.subscribe(Hedgehog.PubSub, "TRADE_EVENTS:#{symbol}")

    {:ok, nil, {:continue, {:start_position, symbol}}}
  end

  def handle_continue({:start_position, symbol}, _state) do
    settings = Formula.fetch_symbol_settings(symbol)
    positions = [Formula.generate_fresh_position(settings)]

    {:noreply, %State{settings: settings, positions: positions}}
  end

  def handle_info(%TradeEvent{} = trade_event, %State{} = state) do
    case Formula.execute(trade_event, state.positions, state.settings) do
      {:ok, updated_positions} ->
        {:noreply, %{state | positions: updated_positions}}

      :exit ->
        {:ok, _settings} = Formula.update_status(trade_event.symbol, :off)
        Logger.info("Trading for #{trade_event.symbol} stopped")
        {:stop, :normal, state}
    end
  end

  def handle_call({:update_settings, new_settings}, _from, state) do
    {:reply, :ok, %{state | settings: new_settings}}
  end

  def handle_call({:get_positions, _symbol}, _from, state) do
    {:reply, state.positions, state}
  end

  defp call_trader(symbol, data) do
    case Registry.lookup(@registry, symbol) do
      [{pid, _}] ->
        GenServer.call(pid, data)

      _ ->
        Logger.warning("Unable to locate trader process assigned to #{symbol}")
        {:error, :unable_to_locate_trader}
    end
  end
end
