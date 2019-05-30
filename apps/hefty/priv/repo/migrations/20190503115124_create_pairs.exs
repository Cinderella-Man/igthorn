defmodule Hefty.Repo.Migrations.CreatePairs do
  use Ecto.Migration

  def change do
    create table(:pairs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      # LTCBTC
      add(:symbol, :text)
      # uuid of BTC
      add(:base_asset_id, references(:balances, type: :uuid))
      # uuid of LTC
      add(:quote_asset_id, references(:balances, type: :uuid))
      # binance's status like "TRADING"
      add(:status, :string)

      timestamps()
    end
  end
end
