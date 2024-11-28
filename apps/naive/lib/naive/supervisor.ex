defmodule Naive.Supervisor do
  use Supervisor

  @registry :naive_traders

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: @registry},
      {Naive.DynamicTraderSupervisor, []},
      {
        Task,
        fn ->
          Naive.DynamicTraderSupervisor.autostart_workers()
        end
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
