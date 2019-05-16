defmodule Hefty.Repo.Binance.TradeEvent do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "trade_events" do
    field(:event_type, :string)
    field(:event_time, :integer)
    field(:symbol, :string)
    field(:trade_id, :integer)
    field(:price, :string)
    field(:quantity, :string)
    field(:buyer_order_id, :integer)
    field(:seller_order_id, :integer)
    field(:trade_time, :integer)
    field(:buyer_market_maker, :boolean)

    timestamps()
  end

end
