defmodule Naive.DynamicSymbolSupervisor do
  use DynamicSupervisor

  require Logger

  alias Naive.Repo
  alias Naive.Schema.Settings

  import Ecto.Query, only: [from: 2]

  @registry :symbol_supervisors

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def autostart_workers() do
    Repo.all(
      from(
        s in Settings,
        where: s.status == :on,
        select: s.symbol
      )
    )
    |> Enum.map(&start_child/1)
  end

  def start_worker(symbol) do
    Logger.info("Starting #{Naive.SymbolSupervisor} worker for #{symbol}")
    update_status(symbol, :on)
    start_child(symbol)
  end

  def stop_worker(symbol) do
    Logger.info("Stopping #{Naive.SymbolSupervisor} worker for #{symbol}")
    update_status(symbol, :off)

    case Registry.lookup(@registry, symbol) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      _ -> Logger.warning("There is no symbol worker for #{symbol}")
    end
  end

  def shutdown_worker(symbol) when is_binary(symbol) do
    case Registry.lookup(@registry, symbol) do
      [{_pid, _}] ->
        Logger.info("Shutting down #{Naive.SymbolSupervisor} worker for #{symbol}")
        {:ok, settings} = update_status(symbol, :shutdown)
        Naive.Leader.notify(:settings_updated, settings)
        {:ok, settings}

      _ ->
        Logger.warning("#{Naive.SymbolSupervisor} worker for #{symbol} already stopped")
        {:ok, _settings} = update_status(symbol, :off)
    end
  end

  defp start_child(symbol) do
    DynamicSupervisor.start_child(__MODULE__, {Naive.SymbolSupervisor, symbol})
  end

  defp update_status(symbol, status) when is_binary(symbol) and is_atom(status) do
    Repo.get_by(Settings, symbol: symbol)
    |> Ecto.Changeset.change(%{status: status})
    |> Repo.update()
  end
end
