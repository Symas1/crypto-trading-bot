defmodule DataWarehouse.Repo do
  use Ecto.Repo, otp_app: :data_warehouse, adapter: Ecto.Adapters.SQLite3
end
