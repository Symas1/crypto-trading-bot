defmodule Naive.DynamicTraderSupervisor do
  use DynamicSupervisor

  require Logger

  alias Naive.Repo
  alias Naive.Schema.Settings
  alias Naive.Strategy

  import Ecto.Query, only: [from: 2]

  @registry :naive_traders

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
    Logger.info("Starting #{Naive.Trader} worker for #{symbol}")
    Strategy.update_status(symbol, :on)
    start_child(symbol)
  end

  def stop_worker(symbol) do
    Logger.info("Stopping #{Naive.Trader} worker for #{symbol}")
    Strategy.update_status(symbol, :off)

    case Registry.lookup(@registry, symbol) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      _ -> Logger.warning("There is no symbol worker for #{symbol}")
    end
  end

  def shutdown_worker(symbol) when is_binary(symbol) do
    Logger.info("Shutdown of #{Naive.Trader}/#{symbol} initialized")
    {:ok, settings} = Strategy.update_status(symbol, :shutdown)
    Naive.Trader.notify(:settings_updated, settings)
    {:ok, settings}
  end

  defp start_child(symbol) do
    DynamicSupervisor.start_child(__MODULE__, {Naive.Trader, symbol})
  end
end
