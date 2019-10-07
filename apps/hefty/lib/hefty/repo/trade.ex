defmodule Hefty.Repo.Trade do
  @moduledoc false

  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}

  schema "trades" do
    field(:symbol, :string)
    field(:buy_price, :string)
    field(:sell_price, :string)
    field(:quantity, :string)
    field(:state, :string)
    field(:buy_time, :integer)
    field(:sell_time, :integer)
    field(:fee_rate, :string)
    field(:profit_base_currency, :string)
    field(:profit_percentage, :string)

    timestamps()
  end
end
