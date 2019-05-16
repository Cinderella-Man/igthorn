defmodule Hefty.Repo.Migrations.CreateBalances do
  use Ecto.Migration

  # Account information user data
  # https://github.com/binance-exchange/binance-official-api-docs/blob/master/rest-api.md#account-information-user_data
  #
  # Each balance is described
  # {
  #   "asset": "BTC",
  #   "free": "4723846.89208129",
  #   "locked": "0.00000000"
  # }

  def change do
    create table(:balances, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :asset, :text
      add :free, :text, default: "0.00000000"
      add :locked, :text, default: "0.00000000"
      add :precision, :integer

      timestamps()
    end
  end
end
