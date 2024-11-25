defmodule Indicator do
  @moduledoc """
  Documentation for `Indicator`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Indicator.hello()
      :world

  """
  def start_ohlcs(symbol) do
    DynamicSupervisor.start_child(
      Indicator.DynamicSupervisor,
      {Indicator.Ohlc.Worker, symbol}
    )
  end
end
