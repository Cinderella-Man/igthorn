defmodule Hefty.Repo.Migrations.CreatePairs do
  use Ecto.Migration

  def change do
    create table(:pairs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :symbol, :text # LTCBTC
      add(:base_asset_id, references(:balances, type: :uuid)) # uuid of BTC
      add(:quote_asset_id, references(:balances, type: :uuid)) # uuid of LTC
      add :status, :string # binance's status like "TRADING"

      timestamps()
    end
  end
end
