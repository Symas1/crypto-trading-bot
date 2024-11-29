defmodule Naive.Strategy do
  alias Decimal, as: D
  alias Core.TradeEvent
  alias Naive.Schema.Settings
  alias Core.Exchange

  require Logger

  @repo Application.compile_env(:naive, :repo)
  @exchange_client Application.compile_env(:naive, :exchange_client)
  @pubsub_client Application.compile_env(:core, :pubsub_client)
  @logger Application.compile_env(:core, :logger)

  defmodule Position do
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

  def fetch_symbol_settings(symbol) do
    {:ok, filters} = @exchange_client.fetch_symbol_filters(symbol)
    settings = @repo.get_by!(Settings, symbol: symbol)

    Map.merge(
      filters |> Map.from_struct(),
      settings |> Map.from_struct()
    )
  end

  def generate_fresh_position(settings, id \\ :os.system_time(:millisecond)) do
    %{
      struct(Position, settings)
      | id: id,
        budget: D.div(settings.budget, settings.chunks),
        rebuy_notified: false
    }
  end

  def execute(%TradeEvent{} = trade_event, positions, settings) do
    generate_decisions(positions, [], trade_event, settings)
    |> Enum.map(fn {decision, position} ->
      Task.async(fn -> execute_decision(decision, position, settings) end)
    end)
    |> Task.await_many()
    |> then(&parse_results/1)
  end

  def generate_decisions([], generated_results, _trade_event, _settings) do
    generated_results
  end

  def generate_decisions([position | rest] = positions, generated_results, trade_event, settings) do
    current_positions = positions ++ (generated_results |> Enum.map(&elem(&1, 0)))

    case generate_decision(trade_event, position, current_positions, settings) do
      :exit ->
        generate_decisions(
          rest,
          generated_results,
          trade_event,
          settings
        )

      :rebuy ->
        generate_decisions(
          rest,
          [{:skip, %{position | rebuy_notified: true}}, {:rebuy, position}] ++ generated_results,
          trade_event,
          settings
        )

      decision ->
        generate_decisions(
          rest,
          [{decision, position} | generated_results],
          trade_event,
          settings
        )
    end
  end

  # Upon trader start receives first trade event and places buy order on that price.
  def generate_decision(
        %TradeEvent{price: price},
        %Position{
          budget: budget,
          buy_order: nil,
          buy_down_interval: buy_down_interval,
          tick_size: tick_size,
          step_size: step_size
        },
        _positions,
        _settings
      ) do
    price = calculate_buy_price(price, buy_down_interval, tick_size)

    quantity = calculate_quantity(budget, price, step_size)

    {:place_buy_order, price, quantity}
  end

  # Deals with the race condition when multiple transactions fill the buy order.
  def generate_decision(
        %TradeEvent{
          buyer_order_id: order_id
        },
        %Position{
          buy_order: %Exchange.Order{
            id: order_id,
            status: :filled
          },
          sell_order: %Exchange.Order{}
        },
        _positions,
        _settings
      )
      when is_number(order_id) do
    :skip
  end

  # Saves buy progress for unfilled buys
  def generate_decision(
        %TradeEvent{buyer_order_id: order_id},
        %Position{
          buy_order: %Exchange.Order{id: order_id},
          sell_order: nil
        },
        _positions,
        _settings
      )
      when is_number(order_id) do
    :fetch_buy_order
  end

  # Places sell order after buy is `FILLED`
  def generate_decision(
        %TradeEvent{},
        %Position{
          buy_order: %Exchange.Order{
            price: buy_price,
            status: :filled
          },
          sell_order: nil,
          profit_interval: profit_interval,
          tick_size: tick_size
        },
        _positions,
        _settings
      ) do
    sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)
    {:place_sell_order, sell_price}
  end

  # Exits for `FILLED` sell
  def generate_decision(
        %TradeEvent{},
        %Position{
          sell_order: %Exchange.Order{status: :filled}
        },
        _positions,
        settings
      ) do
    if settings.status == :shutdown do
      :exit
    else
      :finished
    end
  end

  # Saves sell progress for unfilled sells
  def generate_decision(
        %TradeEvent{seller_order_id: order_id},
        %Position{
          sell_order: %Exchange.Order{id: order_id}
        },
        _positions,
        _settings
      ) do
    :fetch_sell_order
  end

  # Receives trade event and decides, whether price is low enough to trigger rebuy.
  def generate_decision(
        %TradeEvent{price: current_price},
        %Position{
          buy_order: %Exchange.Order{price: buy_price},
          rebuy_interval: rebuy_interval,
          rebuy_notified: false
        },
        positions,
        settings
      ) do
    if settings.status != :shutdown && length(positions) < settings.chunks &&
         trigger_rebuy?(buy_price, current_price, rebuy_interval) do
      :rebuy
    else
      :skip
    end
  end

  # Receives any trade event.
  def generate_decision(%TradeEvent{}, %Position{}, _positions, _settings) do
    :skip
  end

  def calculate_buy_price(current_price, buy_down_interval, tick_size) do
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

  def calculate_sell_price(buy_price, profit_interval, tick_size) do
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

  def calculate_quantity(budget, price, step_size) do
    exact_target_quantity = D.div(budget, price)

    D.to_string(
      D.mult(D.div_int(exact_target_quantity, step_size), step_size),
      :normal
    )
  end

  def trigger_rebuy?(buy_price, current_price, rebuy_interval) do
    rebuy_price =
      D.sub(
        buy_price,
        D.mult(buy_price, rebuy_interval)
      )

    D.lt?(current_price, rebuy_price)
  end

  def update_status(symbol, status) when is_binary(symbol) and is_atom(status) do
    @repo.get_by(Settings, symbol: symbol)
    |> Ecto.Changeset.change(%{status: status})
    |> @repo.update()
  end

  defp execute_decision(
         {:place_buy_order, price, quantity},
         %Position{
           id: id,
           symbol: symbol
         } = position,
         _settings
       ) do
    @logger.info(
      "Position (#{symbol}/#{id}): Placing `buy` order @ #{price}, quantity: #{quantity}"
    )

    {:ok, %Exchange.Order{} = order} =
      @exchange_client.order_limit_buy(symbol, quantity, price)

    :ok = broadcast_order(order)

    {:ok, %{position | buy_order: order}}
  end

  defp execute_decision(
         {:place_sell_order, sell_price},
         %Position{
           id: id,
           symbol: symbol,
           buy_order: %Exchange.Order{
             quantity: quantity
           }
         } = position,
         _settings
       ) do
    @logger.info(
      "Position (#{symbol}/#{id}): Buy order filled, placing SELL order " <>
        "@ #{sell_price}), quantity: #{quantity}"
    )

    {:ok, %Exchange.Order{} = order} =
      @exchange_client.order_limit_sell(symbol, quantity, sell_price)

    :ok = broadcast_order(order)

    {:ok, %{position | sell_order: order}}
  end

  defp execute_decision(
         :fetch_buy_order,
         %Position{
           id: id,
           symbol: symbol,
           buy_order:
             %Exchange.Order{
               id: order_id,
               timestamp: timestamp
             } = buy_order
         } = position,
         _settings
       ) do
    @logger.info("Position (#{symbol}/#{id}): BUY order partially filled")

    {:ok, %Exchange.Order{} = current_buy_order} =
      @exchange_client.get_order(symbol, timestamp, order_id)

    :ok = broadcast_order(current_buy_order)

    buy_order = %{buy_order | status: current_buy_order.status}

    {:ok, %{position | buy_order: buy_order}}
  end

  defp execute_decision(
         :fetch_sell_order,
         %Position{
           id: id,
           symbol: symbol,
           sell_order:
             %Exchange.Order{
               id: order_id,
               timestamp: timestamp
             } = sell_order
         } = position,
         _settings
       ) do
    @logger.info("Position (#{symbol}/#{id}): SELL order partially filled")

    {:ok, %Exchange.Order{} = current_sell_order} =
      @exchange_client.get_order(symbol, timestamp, order_id)

    :ok = broadcast_order(current_sell_order)

    sell_order = %{sell_order | status: current_sell_order.status}

    {:ok, %{position | sell_order: sell_order}}
  end

  defp execute_decision(
         :rebuy,
         %Position{
           id: id,
           symbol: symbol
         },
         settings
       ) do
    @logger.info("Position (#{symbol}/#{id}): Rebuy triggered. Starting new position")
    new_position = generate_fresh_position(settings)
    {:ok, new_position}
  end

  # Receives any trade event.
  defp execute_decision(:skip, position, _settings) do
    {:ok, position}
  end

  defp execute_decision(
         :finished,
         %Position{
           id: id,
           symbol: symbol
         },
         settings
       ) do
    @logger.info("Position (#{symbol}/#{id}): Trade finished")
    {:ok, generate_fresh_position(settings)}
  end

  defp broadcast_order(%Exchange.Order{} = order) do
    @pubsub_client.broadcast(Core.PubSub, "ORDERS:#{order.symbol}", order)
  end

  defp parse_results([]) do
    :exit
  end

  defp parse_results([_ | _] = results) do
    results
    |> Enum.map(fn {:ok, new_position} -> new_position end)
    |> then(&{:ok, &1})
  end
end
