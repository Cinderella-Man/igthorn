defmodule Hefty.Repo.Migrations.CreateNaiveTraderSettings do
  use Ecto.Migration

  def change do
    create table(:naive_trader_settings, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :symbol, :text
      add :budget, :text
      add :profit_interval, :text
      add :buy_down_interval, :text
      add :chunks, :integer
      add :stop_loss_interval, :text
      add :trading, :boolean
      add :streaming, :boolean

      timestamps()
    end
  end
end
