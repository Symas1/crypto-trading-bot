defmodule Naive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {
        DynamicSupervisor,
        strategy: :one_for_one, name: Naive.DynamicSymbolSupervisor
      }
      # Starts a worker by calling: Naive.Worker.start_link(arg)
      # {Naive.Worker, arg}
    ]

    opts = [strategy: :one_for_one, name: Naive.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
