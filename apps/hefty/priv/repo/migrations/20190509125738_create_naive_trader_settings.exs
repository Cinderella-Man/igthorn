defmodule Hefty.Repo.Migrations.CreateNaiveTraderSettings do
  use Ecto.Migration

  def change do
    create table(:naive_trader_settings, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:symbol, :text)
      add(:budget, :text)
      add(:retarget_interval, :text)  # as value goes up away from buy order - how often it should retarted based on current higher price
      add(:profit_interval, :text)    # how much will it grow
      add(:buy_down_interval, :text)  # how much lower buy order price from current price will be
      add(:chunks, :integer)          # number of chunks to split
      add(:stop_loss_interval, :text) # when stop loss should kick in
      add(:rebuy_interval, :text)     # how much lower price needs to drop to buy more (kick off another chunk)
      add(:platform, :text, null: false, default: "Binance")
      add(:trading, :boolean)

      timestamps()
    end
  end
end
