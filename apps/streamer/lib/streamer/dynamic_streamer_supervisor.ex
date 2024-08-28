defmodule Streamer.DynamicStreamerSupervisor do
  use DynamicSupervisor

  require Logger

  alias Streamer.Schema.Settings
  alias Streamer.Repo

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_streaming(symbol) when is_binary(symbol) do
    case get_pid(symbol) do
      nil ->
        Logger.info("Starting streaming on #{symbol}")
        {:ok, _settings} = update_streaming_status(symbol, :on)
        {:ok, _pid} = start_streamer(symbol)

      pid ->
        Logger.warning("Streaming on #{symbol} has already started")
        {:ok, _settings} = update_streaming_status(symbol, :on)
        {:ok, pid}
    end
  end

  defp get_pid(symbol) do
    Process.whereis(:"Elixir.Streamer.Binance-#{symbol}")
  end

  defp update_streaming_status(symbol, status) when is_binary(symbol) and is_atom(status) do
    Repo.get_by(Settings, symbol: symbol)
    |> Ecto.Changeset.change(%{status: status})
    |> Repo.update()
  end

  defp start_streamer(symbol) do
    DynamicSupervisor.start_child(Streamer.DynamicStreamerSupervisor, {Streamer.Binance, symbol})
  end
end
