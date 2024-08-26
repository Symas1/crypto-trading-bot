defmodule Streamer.Schema.Settings do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "settings" do
    field(:symbol, :string)
    field(:status, Ecto.Enum, values: [:on, :off])

    timestamps()
  end
end
