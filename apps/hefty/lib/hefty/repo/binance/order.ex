defmodule Hefty.Repo.Binance.Order do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "orders" do
    belongs_to(:symbol, Hefty.Repo.Binance.Pair, foreign_key: :symbol_id, type: :binary_id)
    field(:orderId, :integer)
    field(:clientOrderId, :string)
    field(:price, :string)
    field(:origQty, :string)
    field(:executedQty, :string)
    field(:cummulativeQuoteQty, :string)
    field(:status, :string)
    field(:timeInForce, :string)
    field(:type, :string)
    field(:side, :string)
    field(:stopPrice, :string)
    field(:icebergQty, :string)
    field(:time, :integer)
    field(:updateTime, :integer)
    field(:isWorking, :boolean)

    timestamps()
  end

  def fetch(_id) do
  end
end
