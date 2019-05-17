defmodule Hefty.Repo.Migrations.CreateStreamingSettings do
  use Ecto.Migration

  def change do
    create table(:streaming_settings, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :symbol, :text, null: false
      add :platform, :text, null: false, default: "Binance"
      add :enabled, :boolean, default: false

      timestamps()
    end
  end
end
