defmodule Core.Exchange.Binance do
  @behaviour Core.Exchange

  alias Core.Exchange

  @impl Exchange
  def fetch_symbols() do
    case Binance.get_exchange_info() do
      {:ok, %{symbols: symbols}} ->
        symbols
        |> Enum.map(& &1["symbol"])
        |> then(&{:ok, &1})

      error ->
        error
    end
  end

  @impl Exchange
  def fetch_symbol_filters(symbol) do
    case Binance.get_exchange_info() do
      {:ok, %{symbols: symbols}} ->
        filters = symbols |> Enum.find(&(&1["symbol"] == symbol)) |> Map.get("filters")

        tick_size =
          filters |> Enum.find(&(&1["filterType"] == "PRICE_FILTER")) |> Map.get("tickSize")

        step_size = filters |> Enum.find(&(&1["filterType"] == "LOT_SIZE")) |> Map.get("stepSize")

        {:ok, %Exchange.SymbolInfo{symbol: symbol, tick_size: tick_size, step_size: step_size}}

      error ->
        error
    end
  end

  @impl Exchange
  def get_order(symbol, timestamp, order_id) do
    case Binance.get_order(symbol, timestamp, order_id) do
      {:ok, %Binance.Order{} = order} ->
        {
          :ok,
          %Exchange.Order{
            id: order.order_id,
            symbol: order.symbol,
            price: order.price,
            quantity: order.orig_qty,
            side: side_to_atom(order.side),
            status: status_to_atom(order.status),
            timestamp: order.time
          }
        }

      error ->
        error
    end
  end

  @impl Exchange
  def order_limit_buy(symbol, quantity, price) do
    case Binance.order_limit_buy(symbol, quantity, price, "GTC") do
      {:ok, %Binance.OrderResponse{} = order} ->
        {
          :ok,
          %Exchange.Order{
            id: order.order_id,
            symbol: order.symbol,
            price: order.price,
            quantity: order.orig_qty,
            side: :buy,
            status: :new,
            timestamp: order.transact_time
          }
        }

      error ->
        error
    end
  end

  @impl Exchange
  def order_limit_sell(symbol, quantity, price) do
    case Binance.order_limit_sell(symbol, quantity, price, "GTC") do
      {:ok, %Binance.OrderResponse{} = order} ->
        {
          :ok,
          %Exchange.Order{
            id: order.order_id,
            symbol: order.symbol,
            price: order.price,
            quantity: order.orig_qty,
            side: :sell,
            status: :new,
            timestamp: order.transact_time
          }
        }

      error ->
        error
    end
  end

  defp side_to_atom("BUY"), do: :buy
  defp side_to_atom("SELL"), do: :sell
  defp status_to_atom("NEW"), do: :new
  defp status_to_atom("FILLED"), do: :filled
end
