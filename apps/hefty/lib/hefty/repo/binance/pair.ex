defmodule Hefty.Repo.Binance.Pair do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "pairs" do
    field(:symbol, :string)
    belongs_to(:base_asset, Hefty.Repo.Binance.Balance, foreign_key: :base_asset_id, type: :binary_id)
    belongs_to(:quote_asset, Hefty.Repo.Binance.Balance, foreign_key: :quote_asset_id, type: :binary_id)
    field(:status, :string)

    timestamps()
  end

end
