defmodule BinanceMock do
  use GenServer

  alias Decimal, as: D
  alias Streamer.Binance.TradeEvent

  require Logger

  defmodule State do
    defstruct order_books: %{}, subscriptions: [], fake_order_id: 1
  end

  defmodule OrderBook do
    defstruct buy_side: [], sell_size: [], historical: []
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(args) do
    {:ok, %State{}}
  end

  def handle_cast(
        {:add_order, %Binance.Order{symbol: symbol}},
        %State{order_books: order_books, subscriptions: subscriptions} = state
      ) do
    new_subscriptions = subscribe_to_topic(symbol, subscriptions)
    updated_order_books = add_order(order, order_books)

    {:noreply,
     %{
       state
       | order_books: updated_order_books,
         subscriptions: new_subscriptions
     }}
  end

  def handle_call(:generate_id, _from, %State{fake_order_id: id} = state) do
    {:reply, id + 1, %{state | fake_order_id: id + 1}}
  end

  def get_exchange_info do
    Binance.get_exchange_info()
  end

  def order_limit_buy(symbol, quantity, price, "GTC") do
    order_limit(symbol, quantity, price, "BUY")
  end

  def order_limit_sell(symbol, quantity, price, "GTC") do
    order_limit(symbol, quantity, price, "SELL")
  end

  defp order_limit(symbol, quantity, price, side) do
    %Binance.Order{} = fake_order = generate_fake_order(symbol, quantity, price, side)

    GenServer.cast(__MODULE__, {:add_order, fake_order})

    {:ok, convert_order_to_order_response(fake_order)}
  end

  defp subscribe_to_topic(symbol, subscriptions) do
    symbol = String.upcase(symbol)
    stream_name = "TRADE_EVENTS:#{symbol}"

    case Enum.member?(subscriptions, symbol) do
      false ->
        Logger.debug("BinanceMock subscribing to #{stream_name}")

        Phoenix.PubSub.subscribe(
          Streamer.PubSub,
          stream_name
        )

        [symbol | subscriptions]

      _ ->
        subscriptions
    end
  end

  defp add_order(
         %Binance.Order{symbol: symbol} = order,
         order_books
       ) do
    order_book =
      Map.get(
        order_books,
        :"#{symbol}",
        %OrderBook{}
      )

    order_book =
      if order.size == "SELL" do
        Map.replace!(
          order_book,
          :sell_side,
          [order | order_book.sell_side]
          |> Enum.sort(&D.lt?(&1.price, &2.price))
        )
      else
        Map.replace!(
          order_book,
          :buy_side,
          [order | order_book.buy_side]
          |> Enum.sort(&D.gt?(&1.price, &2.price))
        )
      end

    Map.put(order_books, :"#{symbol}", order_book)
  end

  defp generate_fake_order(symbol, quantity, price, side)
       when is_binary(symbol) and
              is_binary(quantity) and
              is_binary(price) and
              (side == "BUY" or side == "SELL") do
    current_timestamp = :os.system_time(:millisecond)
    order_id = GenServer.call(__MODULE__, :generate_id)
    client_order_id = :crypto.hash(:md5, "#{order_id}" |> Base.encode16())

    Binance.Order.new(%{
      symbol: symbol,
      order_id: order_id,
      client_order_id: client_order_id,
      price: price,
      orig_qty: quantity,
      executed_qty: "0.00000000",
      cummulative_quote_qty: "0.00000000",
      status: "NEW",
      time_in_force: "GTC",
      type: "LIMIT",
      side: side,
      stop_price: "0.00000000",
      iceberg_qty: "0.00000000",
      time: current_timestamp,
      update_time: current_timestamp,
      is_working: true
    })
  end

  defp convert_order_to_order_response(%Binance.Order{} = order) do
    %{
      struct(
        Binance.OrderResponse,
        order |> Map.to_list()
      )
      | transact_time: order.time
    }
  end
end
