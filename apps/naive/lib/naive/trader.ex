defmodule Naive.Trader do
  use GenServer, restart: :temporary

  alias Core.TradeEvent
  alias Decimal, as: D

  require Logger

  @binance_client Application.compile_env(:naive, :binance_client)
  @leader Application.compile_env(:naive, :leader)
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

  # Upon trader start receives first trade event and places buy order on that price.
  def handle_info(
        %TradeEvent{price: price},
        %State{
          id: id,
          symbol: symbol,
          buy_order: nil,
          buy_down_interval: buy_down_interval,
          tick_size: tick_size,
          budget: budget,
          step_size: step_size
        } = state
      ) do
    price = calculate_buy_price(price, buy_down_interval, tick_size)

    quantity = calculate_quantity(budget, price, step_size)

    @logger.info("[#{id}] Placing `buy` order for #{symbol} @ #{price}, quantity: #{quantity}")

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_buy(symbol, quantity, price, "GTC")

    :ok = broadcast_order(order)

    new_state = %{state | buy_order: order}
    @leader.notify(:trader_state_updated, new_state)
    {:noreply, new_state}
  end

  # Skips `buy` trade events for our `order_id`, if buy_order filled and sell_order placed.
  def handle_info(
        %TradeEvent{buyer_order_id: order_id},
        %State{
          buy_order: %Binance.OrderResponse{
            # confirms that it's event for buy order
            order_id: order_id,
            # confirms buy order filled
            status: "FILLED"
          },
          # confirms sell order placed
          sell_order: %Binance.OrderResponse{}
        } = state
      ) do
    {:noreply, state}
  end

  # Places sell order after buy is `FILLED`
  def handle_info(
        %TradeEvent{},
        %State{
          id: id,
          symbol: symbol,
          buy_order: %Binance.OrderResponse{
            price: buy_price,
            orig_qty: quantity,
            status: "FILLED"
          },
          sell_order: nil,
          profit_interval: profit_interval,
          tick_size: tick_size
        } = state
      ) do
    sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)

    @logger.info(
      "[#{id}] Buy order filled, placing SELL order for " <>
        "#{symbol} @ #{sell_price}), quantity: #{quantity}"
    )

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_sell(symbol, quantity, sell_price, "GTC")

    :ok = broadcast_order(order)

    new_state = %{state | sell_order: order}
    @leader.notify(:trader_state_updated, new_state)
    {:noreply, new_state}
  end

  # Saves buy progress for unfilled buys
  def handle_info(
        %TradeEvent{buyer_order_id: order_id},
        %State{
          id: id,
          symbol: symbol,
          buy_order:
            %Binance.OrderResponse{
              order_id: order_id,
              transact_time: timestamp
            } = buy_order
        } = state
      ) do
    @logger.info("[#{id}] BUY order partially filled")
    {:ok, %{state | buy_order: buy_order}}

    {:ok, %Binance.Order{} = current_buy_order} =
      @binance_client.get_order(symbol, timestamp, order_id)

    :ok = broadcast_order(current_buy_order)

    buy_order = %{buy_order | status: current_buy_order.status}

    new_state = %{state | buy_order: buy_order}
    @leader.notify(:trader_state_updated, new_state)
    {:noreply, new_state}
  end

  # Exits for `FILLED` sell
  def handle_info(
        %TradeEvent{},
        %State{
          id: id,
          sell_order: %Binance.OrderResponse{
            status: "FILLED"
          }
        } = state
      ) do
    @logger.info("[#{id}] Trade finished, trader will now exit")
    {:stop, :normal, state}
  end

  # Saves sell progress for unfilled sells
  def handle_info(
        %TradeEvent{seller_order_id: order_id},
        %State{
          id: id,
          symbol: symbol,
          sell_order:
            %Binance.OrderResponse{
              order_id: order_id,
              transact_time: timestamp
            } = sell_order
        } = state
      ) do
    @logger.info("[#{id}] SELL order partially filled")

    {:ok, %Binance.Order{} = current_sell_order} =
      @binance_client.get_order(symbol, timestamp, order_id)

    :ok = broadcast_order(current_sell_order)

    sell_order = %{sell_order | status: current_sell_order.status}

    new_state = %{state | sell_order: sell_order}
    @leader.notify(:trader_state_updated, new_state)
    {:ok, new_state}
  end

  # Receives trade event and decides, whether price is low enough to trigger rebuy.
  def handle_info(
        %TradeEvent{price: current_price},
        %State{
          id: id,
          symbol: symbol,
          buy_order: %Binance.OrderResponse{price: buy_price},
          rebuy_interval: rebuy_interval,
          rebuy_notified: false
        } = state
      ) do
    if trigger_rebuy?(buy_price, current_price, rebuy_interval) do
      @logger.info("[#{id}] Rebuy triggered for #{symbol} trader")
      new_state = %{state | rebuy_notified: true}
      @leader.notify(:rebuy_triggered, new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  # Receives any trade event.
  def handle_info(%TradeEvent{}, state) do
    {:noreply, state}
  end

  defp calculate_buy_price(current_price, buy_down_interval, tick_size) do
    # may be invalid price (not divisible by tick_size)
    exact_buy_price =
      D.sub(
        current_price,
        D.mult(current_price, buy_down_interval)
      )

    D.to_string(
      D.mult(
        D.div_int(exact_buy_price, tick_size),
        tick_size
      ),
      :normal
    )
  end

  defp calculate_sell_price(buy_price, profit_interval, tick_size) do
    # TODO: remove hardcoded value
    fee = "1.001"

    original_price = D.mult(buy_price, fee)

    net_target_price = D.mult(original_price, D.add("1.0", profit_interval))

    gross_target_price = D.mult(net_target_price, fee)

    D.to_string(
      D.mult(
        D.div_int(gross_target_price, tick_size),
        tick_size
      ),
      :normal
    )
  end

  defp calculate_quantity(budget, price, step_size) do
    exact_target_quantity = D.div(budget, price)

    D.to_string(
      D.mult(D.div_int(exact_target_quantity, step_size), step_size),
      :normal
    )
  end

  defp trigger_rebuy?(buy_price, current_price, rebuy_interval) do
    rebuy_price =
      D.sub(
        buy_price,
        D.mult(buy_price, rebuy_interval)
      )

    D.lt?(current_price, rebuy_price)
  end

  defp broadcast_order(%Binance.OrderResponse{} = response) do
    response |> to_order() |> broadcast_order()
  end

  defp broadcast_order(%Binance.Order{} = order) do
    @pubsub_client.broadcast(Core.PubSub, "ORDERS:#{order.symbol}", order)
  end

  defp to_order(%Binance.OrderResponse{} = response) do
    raw = response |> Map.from_struct()

    struct(Binance.Order, raw)
    |> Map.merge(%{
      cummulative_quote_qty: "0.00000000",
      stop_price: "0.00000000",
      iceberg_qty: "0.00000000",
      is_working: true
    })
  end
end
