defmodule Hedgehog.Data.Collector.DynamicWorkerSupervisor do
  use DynamicSupervisor

  require Logger

  alias Hedgehog.Repo
  alias Hedgehog.Data.Collector.Settings
  alias Hedgehog.Data.Collector.Worker

  import Ecto.Query, only: [from: 2]

  @registry :collector_workers

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
        select: s.topic
      )
    )
    |> Enum.map(&start_child/1)
  end

  def start_worker(topic) do
    Logger.info("Starting storing data from #{topic} topic")
    update_status(topic, :on)
    start_child(topic)
  end

  def stop_worker(topic) do
    Logger.info("Stopping storing data from #{topic} topic")
    update_status(topic, :off)
    stop_child(topic)
  end

  defp start_child(settings) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Worker, settings}
    )
  end

  defp stop_child(args) do
    case Registry.lookup(@registry, args) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      _ -> Logger.warning("Unable to locate process assigned to #{inspect(args)}")
    end
  end

  defp update_status(topic, status) when is_binary(topic) and is_atom(status) do
    %Settings{
      topic: topic,
      status: status
    }
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: :topic
    )
  end
end
