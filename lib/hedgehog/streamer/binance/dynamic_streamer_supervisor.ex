defmodule Hedgehog.Streamer.Binance.DynamicStreamerSupervisor do
  use DynamicSupervisor

  require Logger

  alias Hedgehog.Repo
  alias Hedgehog.Streamer.Binance.Worker
  alias Hedgehog.Streamer.Settings

  import Ecto.Query, only: [from: 2]

  @registry :streamer_workers

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def autostart_workers() do
    Repo.all(
      from(s in Settings,
        where: s.status == :on,
        select: s.symbol
      )
    )
    |> Enum.map(&start_child/1)
  end

  def start_worker(symbol) do
    Logger.info("Starting streaming for #{symbol}")
    update_status(symbol, :on)
    start_child(symbol)
  end

  def stop_worker(symbol) do
    Logger.info("Stopping streaming for #{symbol}")
    update_status(symbol, :off)

    case Registry.lookup(@registry, symbol) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      _ -> Logger.warning("No streaming process for #{symbol}")
    end
  end

  defp start_child(symbol) do
    DynamicSupervisor.start_child(__MODULE__, {Worker, symbol})
  end

  defp update_status(symbol, status) when is_binary(symbol) and is_atom(status) do
    Repo.get_by(Settings, symbol: symbol)
    |> Ecto.Changeset.change(%{status: status})
    |> Repo.update()
  end
end
