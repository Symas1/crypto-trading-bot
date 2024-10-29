defmodule Core.ServiceSupervisor do
  require Logger

  import Ecto.Query, only: [from: 2]

  def autostart_workers(repo, schema, module, worker_module) do
    fetch_symbols_to_start(repo, schema)
    |> Enum.map(&start_worker(&1, repo, schema, module, worker_module))
  end

  def start_worker(symbol, repo, schema, module, worker_module) when is_binary(symbol) do
    case get_pid(worker_module, symbol) do
      nil ->
        Logger.info("Starting #{worker_module} worker for #{symbol}")
        {:ok, _settings} = update_status(symbol, :on, repo, schema)

        {:ok, _pid} =
          DynamicSupervisor.start_child(
            module,
            {worker_module, symbol}
          )

      pid ->
        Logger.warning("#{worker_module} worker for #{symbol} already started")
        {:ok, _settings} = update_status(symbol, :on, repo, schema)
        {:ok, pid}
    end
  end

  def stop_worker(symbol, repo, schema, module, worker_module) when is_binary(symbol) do
    case get_pid(worker_module, symbol) do
      nil ->
        Logger.warning("#{worker_module} worker for #{symbol} already stopped")
        {:ok, _settings} = update_status(symbol, :off, repo, schema)

      pid ->
        Logger.info("Stopping #{worker_module} worker for #{symbol}")
        :ok = DynamicSupervisor.terminate_child(module, pid)
        {:ok, _settings} = update_status(symbol, :off, repo, schema)
    end
  end

  def get_pid(worker_module, symbol) do
    Process.whereis(:"#{worker_module}-#{symbol}")
  end

  def update_status(symbol, status, repo, schema) when is_binary(symbol) and is_atom(status) do
    repo.get_by(schema, symbol: symbol)
    |> Ecto.Changeset.change(%{status: status})
    |> repo.update()
  end

  defp fetch_symbols_to_start(repo, schema) do
    repo.all(
      from(s in schema,
        where: s.status == :on,
        select: s.symbol
      )
    )
  end
end
