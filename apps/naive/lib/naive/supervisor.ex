defmodule Naive.Supervisor do
  use Supervisor

  @registry :symbol_supervisors

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: @registry},
      {Naive.DynamicSymbolSupervisor, []},
      {
        Task,
        fn ->
          Naive.DynamicSymbolSupervisor.autostart_workers()
        end
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
