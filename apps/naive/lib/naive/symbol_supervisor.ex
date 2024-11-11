defmodule Naive.SymbolSupervisor do
  use Supervisor

  require Logger

  @registry :symbol_supervisors

  def start_link(symbol) do
    Supervisor.start_link(
      __MODULE__,
      symbol,
      name: {:via, Registry, {@registry, symbol}}
    )
  end

  def init(symbol) do
    Logger.info("Starting new supervision tree to trade on #{symbol}")

    Supervisor.init(
      [
        {
          DynamicSupervisor,
          strategy: :one_for_one, name: :"Naive.DynamicTraderSupervisor-#{symbol}"
        },
        {Naive.Leader, symbol}
      ],
      strategy: :one_for_all
    )
  end
end
