defmodule DataWarehouse.Repo.Migrations.CreateSubscriberSettings do
  use Ecto.Migration

  def change do
    create table(:subscriber_settings, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:topic, :text, null: false)
      add(:status, :text, default: "off", null: false)

      timestamps()
    end

    create(unique_index(:subscriber_settings, [:topic]))
  end
end
