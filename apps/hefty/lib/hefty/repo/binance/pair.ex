defmodule Hefty.Repo.Binance.Pair do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "pairs" do
    field(:symbol, :string)

    belongs_to(:base_asset, Hefty.Repo.Binance.Balance,
      foreign_key: :base_asset_id,
      type: :binary_id
    )

    belongs_to(:quote_asset, Hefty.Repo.Binance.Balance,
      foreign_key: :quote_asset_id,
      type: :binary_id
    )

    # parts of price filter
    field(:min_price, :string)
    field(:max_price, :string)
    field(:tick_size, :string)

    # lot size filter
    field(:min_quantity, :string)
    field(:max_quantity, :string)
    field(:step_size, :string)

    field(:status, :string)

    timestamps()
  end
end
