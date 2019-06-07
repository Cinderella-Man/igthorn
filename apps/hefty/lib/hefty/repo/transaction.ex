defmodule Hefty.Repo.Transaction do
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "transactions" do
    belongs_to(:order, Hefty.Repo.Order, foreign_key: :order_id, type: :binary_id)
    field(:price, :string)
    field(:quantity, :string)
    field(:commission, :string)
    field(:commission_asset, :string)

    timestamps()
  end

  def fetch_transaction(id) do
    query = from(t in __MODULE__,
      where: t.id == ^id
    )

    Hefty.Repo.one(query)
  end
end
