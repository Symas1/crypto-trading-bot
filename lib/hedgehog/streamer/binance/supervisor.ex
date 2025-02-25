defmodule Hedgehog.Streamer.Binance.Supervisor do
  use Supervisor

  alias Hedgehog.Streamer.Binance.DynamicStreamerSupervisor

  @registry :streamer_workers

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: @registry},
      {DynamicStreamerSupervisor, []},
      {Task, fn -> DynamicStreamerSupervisor.autostart_workers() end}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
