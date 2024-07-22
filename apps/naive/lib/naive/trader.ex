defmodule State do
  @enforce_keys [:symbol, :profit_interval, :tick_size]
  defstruct [
    :symbol,
    :buy_order,
    :sell_order,
    :profit_interval,
    :tick_size
  ]
end

defmodule Naive.Trader do
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: :trader)
  end

  def init(args) do
    {:ok, args}
  end
end
