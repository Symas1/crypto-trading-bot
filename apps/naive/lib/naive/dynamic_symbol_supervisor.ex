defmodule Naive.DynamicSymbolSupervisor do
  use DynamicSupervisor

  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defdelegate autostart_workers(), to: Core.ServiceSupervisor
  defdelegate start_worker(symbol), to: Core.ServiceSupervisor
  defdelegate stop_worker(symbol), to: Core.ServiceSupervisor

  def shutdown_worker(symbol) when is_binary(symbol) do
    symbol = String.upcase(symbol)

    case Core.ServiceSupervisor.get_pid(symbol) do
      nil ->
        Logger.warning("Trading on #{symbol} already stopped")
        {:ok, _settings} = Core.ServiceSupervisor.update_status(symbol, :off)

      _pid ->
        Logger.info("Shutting down trading on #{symbol}")
        {:ok, settings} = Core.ServiceSupervisor.update_status(symbol, :shutdown)
        Naive.Leader.notify(:settings_updated, settings)
        {:ok, settings}
    end
  end
end
