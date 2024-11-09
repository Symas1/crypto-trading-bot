defmodule Streamer.Supervisor do
  use Supervisor

  @registry :streamer_workers

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: @registry},
      {Streamer.DynamicStreamerSupervisor, []},
      {Task, fn -> Streamer.DynamicStreamerSupervisor.autostart_workers() end}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
