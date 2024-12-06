defmodule Hedgehog.Strategy.Naive.DynamicTraderSupervisor do
  use DynamicSupervisor

  require Logger

  alias Hedgehog.Repo
  alias Hedgehog.Strategy.Naive.Settings
  alias Hedgehog.Strategy.Naive.Formula
  alias Hedgehog.Strategy.Naive.Trader

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
    Logger.info("Starting #{Trader} worker for #{symbol}")
    Formula.update_status(symbol, :on)
    start_child(symbol)
  end

  def stop_worker(symbol) do
    Logger.info("Stopping #{Trader} worker for #{symbol}")
    Formula.update_status(symbol, :off)

    case Registry.lookup(@registry, symbol) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      _ -> Logger.warning("There is no symbol worker for #{symbol}")
    end
  end

  def shutdown_worker(symbol) when is_binary(symbol) do
    Logger.info("Shutdown of #{Trader}/#{symbol} initialized")
    {:ok, settings} = Formula.update_status(symbol, :shutdown)
    Trader.notify(:settings_updated, settings)
    {:ok, settings}
  end

  defp start_child(symbol) do
    DynamicSupervisor.start_child(__MODULE__, {Trader, symbol})
  end
end
