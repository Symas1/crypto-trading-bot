defmodule Hedgehog.Data.Aggregator do
  alias Hedgehog.Data.Aggregator.Ohlc.Worker

  def aggregate_ohlcs(symbol) do
    DynamicSupervisor.start_child(
      Hedgehog.Data.Aggregator.DynamicSupervisor,
      {Worker, symbol}
    )
  end
end
