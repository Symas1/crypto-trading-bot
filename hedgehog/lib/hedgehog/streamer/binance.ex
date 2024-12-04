defmodule Hedgehog.Streamer.Binance do
  alias Hedgehog.Streamer.Binance.DynamicStreamerSupervisor

  def start_streaming(symbol) do
    symbol |> String.upcase() |> DynamicStreamerSupervisor.start_worker()
  end

  def stop_streaming(symbol) do
    symbol |> String.upcase() |> DynamicStreamerSupervisor.stop_worker()
  end
end
