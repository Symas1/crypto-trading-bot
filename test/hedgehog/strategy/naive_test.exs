defmodule Hedgehog.Strategy.NaiveTest do
  use ExUnit.Case
  doctest Hedgehog.Strategy.Naive

  alias Hedgehog.Strategy.Naive
  alias Hedgehog.Exchange.Order
  alias Hedgehog.Data.Collector
  alias Hedgehog.Exchange.TradeEvent
  alias Hedgehog.Strategy.Naive.Settings, as: TradingSettings
  alias Hedgehog.Repo

  import Ecto.Query, only: [from: 2]

  @tag integration: true
  test "Naive trader full trade(buy + sell) test" do
    symbol = "XRPUSDT"

    # Step 1 - Update trading settings

    settings = [
      profit_interval: 0.001,
      buy_down_interval: 0.0025,
      chunks: 5,
      budget: 100.0
    ]

    {:ok, _} =
      TradingSettings
      |> Repo.get_by!(symbol: symbol)
      |> Ecto.Changeset.change(settings)
      |> Repo.update()

    # Step 2 - Start trading on symbol

    Naive.start_trading(symbol)

    # Step 3 - Start storing orders
    Collector.start_storing("ORDERS", "XRPUSDT")
    :timer.sleep(5000)

    # Step 4 - Broadcast events
    [
      # buy order palced @ 0.4307
      generate_event(1, "0.43183010", "213.10000000"),
      generate_event(2, "0.43183020", "56.10000000"),
      generate_event(3, "0.43183030", "12.10000000"),
      # event at the expected buy price
      generate_event(4, "0.4307", "38.92000000"),
      # event below the expected buy price
      # trigger fake fill event for placed buy order
      generate_event(5, "0.43065", "126.53000000"),
      # palce sell order @ 0.4319
      generate_event(6, "0.43065", "126.53000000"),
      # event below the expected sell price
      generate_event(7, "0.43189", "26.18500000"),
      # event at exact the expected sell price
      generate_event(8, "0.4319", "62.92640000"),
      # event above the expected sell price
      # it should trigger fake fill event for placed sell order
      generate_event(9, "0.43205", "345.14235000"),
      # finish trader
      generate_event(10, "0.43205", "345.14235000"),
      # trigger buy order for a new trader process
      generate_event(11, "0.43210", "3201.86480000")
    ]
    |> Enum.each(fn event ->
      Phoenix.PubSub.broadcast(
        Hedgehog.PubSub,
        "TRADE_EVENTS:#{symbol}",
        event
      )

      :timer.sleep(10)
    end)

    :timer.sleep(2000)

    # Step 5 - Check orders table
    query =
      from(o in Order,
        select: [o.price, o.side, o.status],
        order_by: o.inserted_at,
        where: o.symbol == ^symbol
      )

    [buy_1, sell_1, buy_2] = Repo.all(query)

    assert buy_1 == ["0.43070000", "BUY", "FILLED"]
    assert sell_1 == ["0.43190000", "SELL", "FILLED"]
    assert buy_2 == ["0.43100000", "BUY", "NEW"]
  end

  defp generate_event(id, price, quantity) do
    %TradeEvent{
      event_type: "trade",
      event_time: 1_000 + id * 10,
      symbol: "XRPUSDT",
      trade_id: 2_000 + id * 10,
      price: price,
      quantity: quantity,
      buyer_order_id: 3_000 + id * 10,
      seller_order_id: 4_000 + id * 10,
      trade_time: 5_000 + id * 10,
      buyer_market_maker: false
    }
  end
end
