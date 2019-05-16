defmodule Hefty.Repo.Migrations.CreateTradeEvents do
  use Ecto.Migration

  # State as of 30/04
  # {
  #   "e": "trade",     // Event type
  #   "E": 123456789,   // Event time
  #   "s": "BNBBTC",    // Symbol
  #   "t": 12345,       // Trade ID
  #   "p": "0.001",     // Price
  #   "q": "100",       // Quantity
  #   "b": 88,          // Buyer order ID
  #   "a": 50,          // Seller order ID
  #   "T": 123456785,   // Trade time
  #   "m": true,        // Is the buyer the market maker?
  #   "M": true         // Ignore
  # }

  def change do
    create table(:trade_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :event_type, :text
      add :event_time, :bigint
      add :symbol, :text
      add :trade_id, :integer
      add :price, :text
      add :quantity, :text
      add :buyer_order_id, :bigint
      add :seller_order_id, :bigint
      add :trade_time, :bigint
      add :buyer_market_maker, :bool

      timestamps()
    end
  end
end
