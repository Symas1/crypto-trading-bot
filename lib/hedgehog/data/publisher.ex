defmodule Hedgehog.Data.Publisher do
  require Logger
  use Task

  alias Hedgehog.Repo
  alias Hedgehog.Exchange.TradeEvent

  import Ecto.Query, only: [from: 2]

  def start_link(settings) do
    Task.start_link(__MODULE__, :run, [settings])
  end

  def run(%{
        type: :trade_events,
        symbol: symbol,
        from: from,
        to: to,
        interval: interval
      }) do
    symbol = String.upcase(symbol)

    from_ts =
      "#{from}T00:00:00.000Z"
      |> convert_to_ms()

    to_ts =
      "#{to}T23:59:59.000Z"
      |> convert_to_ms()

    Repo.transaction(
      fn ->
        from(
          te in TradeEvent,
          where:
            te.symbol == ^symbol and
              te.trade_time >= ^from_ts and
              te.trade_time <= ^to_ts,
          order_by: te.trade_time
        )
        |> Repo.stream()
        |> Enum.with_index()
        |> Enum.map(fn {row, index} ->
          :timer.sleep(interval)

          if rem(index, 10_000) == 0 do
            Logger.info("Publisher broadcasted #{index} events")
          end

          publish_trade_event(row)
        end)
      end,
      timeout: :infinity
    )

    Logger.info("Publisher finished streaming trade events")
  end

  defp convert_to_ms(iso8601DateString) do
    iso8601DateString
    |> NaiveDateTime.from_iso8601!()
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
    |> Kernel.*(1000)
  end

  defp publish_trade_event(%TradeEvent{} = trade_event) do
    streamer_trade_event =
      struct(
        TradeEvent,
        trade_event |> Map.to_list()
      )

    Phoenix.PubSub.broadcast(
      Hedgehog.PubSub,
      "TRADE_EVENTS:#{trade_event.symbol}",
      streamer_trade_event
    )
  end
end
