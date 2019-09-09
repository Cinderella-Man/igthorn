defmodule Hefty.Repo.Migrations.CreateTrades do
  use Ecto.Migration

  def change do
    create table(:trades, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:symbol, :text, null: false)
      add(:buy_price, :text, null: false)
      add(:sell_price, :text)
      add(:quantity, :text, null: false)
      add(:state, :text, null: false)
      add(:buy_time, :bigint, null: false)
      add(:sell_time, :bigint)
      add(:fee_rate, :text, null: false)
      add(:profit_base_currency, :text)
      add(:profit_percentage, :text)

      timestamps()
    end
  end
end
