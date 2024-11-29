defmodule DataWarehouse.Subscriber.Worker do
  use GenServer

  alias Core.Exchange

  require Logger

  defmodule State do
    @enforce_keys [:topic]
    defstruct [:topic]
  end

  def start_link(topic) do
    GenServer.start_link(
      __MODULE__,
      topic,
      name: {:via, Registry, {:subscriber_workers, topic}}
    )
  end

  def init(topic) do
    Logger.info("DataWarehouse worker is subscribing to topic #{topic}")

    Phoenix.PubSub.subscribe(Core.PubSub, topic)

    {:ok, %State{topic: topic}}
  end

  def handle_info(%Core.TradeEvent{} = trade_event, state) do
    opts = trade_event |> Map.from_struct()

    struct!(DataWarehouse.Schema.TradeEvent, opts) |> DataWarehouse.Repo.insert()

    {:noreply, state}
  end

  def handle_info(%Exchange.Order{} = order, state) do
    data =
      order
      |> Map.from_struct()
      |> Map.merge(%{side: atom_to_side(order.side), status: atom_to_status(order.status)})

    struct(DataWarehouse.Schema.Order, data)
    |> DataWarehouse.Repo.insert(
      on_conflict: :replace_all,
      conflict_target: :id
    )

    {:noreply, state}
  end

  defp atom_to_side(:buy), do: "BUY"
  defp atom_to_side(:sell), do: "SELL"
  defp atom_to_status(:new), do: "NEW"
  defp atom_to_status(:filled), do: "FILLED"
end
