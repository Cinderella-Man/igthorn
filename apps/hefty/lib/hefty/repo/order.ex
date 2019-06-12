defmodule Hefty.Repo.Order do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "orders" do
    # belongs_to(:symbol, Hefty.Repo.Binance.Pair, foreign_key: :symbol_id, type: :binary_id)
    field(:order_id, :integer)
    field(:symbol, :string)
    field(:client_order_id, :string)
    field(:price, :string)
    field(:original_quantity, :string)
    field(:executed_quantity, :string)
    field(:cummulative_quote_quantity, :string)
    field(:status, :string)
    field(:time_in_force, :string)
    field(:type, :string)
    field(:side, :string)
    field(:stop_price, :string)
    field(:iceberg_quantity, :string)
    field(:time, :integer)
    field(:update_time, :integer)
    field(:is_working, :boolean)
    field(:strategy, :string)
    field(:matching_order, :string)

    timestamps()
  end

  def fetch(_id) do
  end
end
