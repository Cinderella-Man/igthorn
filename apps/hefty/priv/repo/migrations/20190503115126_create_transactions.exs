defmodule Hefty.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  # Make order
  # https://github.com/binance-exchange/binance-official-api-docs/blob/master/rest-api.md#new-order--trade
  #
  # Each transaction is described
  # {
  #   "price": "4000.00000000",
  #   "qty": "1.00000000",
  #   "commission": "4.00000000",
  #   "commissionAsset": "USDT"
  # }

  def change do
    create table(:transactions, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      # uuid of LTCBTC
      add(:order_id, references(:orders, type: :uuid))
      add(:price, :text)
      add(:quantity, :text)
      add(:commission, :text)
      add(:commission_asset, :text)

      timestamps()
    end
  end
end
