defmodule Streamer do
  @moduledoc """
  Documentation for `Streamer`.
  """

  alias Streamer.DynamicStreamerSupervisor

  def start_streaming(symbol) do
    symbol |> String.upcase() |> DynamicStreamerSupervisor.start_streaming()
  end
end
