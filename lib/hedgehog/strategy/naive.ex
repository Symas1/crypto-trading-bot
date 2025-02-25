defmodule Hedgehog.Strategy.Naive do
  alias Hedgehog.Strategy.Naive.DynamicTraderSupervisor
  alias Hedgehog.Strategy.Naive.Trader

  def start_trading(symbol) do
    symbol |> String.upcase() |> DynamicTraderSupervisor.start_worker()
  end

  def stop_trading(symbol) do
    symbol |> String.upcase() |> DynamicTraderSupervisor.stop_worker()
  end

  def shutdown_trading(symbol) do
    symbol |> String.upcase() |> DynamicTraderSupervisor.shutdown_worker()
  end

  def get_positions(symbol) do
    symbol
    |> String.upcase()
    |> Trader.get_positions()
  end
end
