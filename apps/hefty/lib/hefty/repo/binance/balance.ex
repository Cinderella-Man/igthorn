defmodule Hefty.Repo.Binance.Balance do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "balances" do
    field(:asset, :string)
    field(:free, :string)
    field(:locked, :string)
    field(:precision, :integer)

    timestamps()
  end
end
