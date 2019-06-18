defmodule Hefty.Repo.Migrations.CreatePairs do
  use Ecto.Migration

  # Exchange info (list of pairs)
  # https://github.com/binance-exchange/binance-official-api-docs/blob/master/rest-api.md#exchange-information
  #
  # %{
  #   "baseAsset" => "STRAT",
  #   "baseAssetPrecision" => 8,
  #   "filters" => [
  #     %{
  #       "filterType" => "PRICE_FILTER",
  #       "maxPrice" => "100000.00000000",
  #       "minPrice" => "0.00000010",
  #       "tickSize" => "0.00000010"
  #     },
  #     %{
  #       "avgPriceMins" => 5,
  #       "filterType" => "PERCENT_PRICE",
  #       "multiplierDown" => "0.2",
  #       "multiplierUp" => "5"
  #     },
  #     %{
  #       "filterType" => "LOT_SIZE",
  #       "maxQty" => "90000000.00000000",
  #       "minQty" => "0.01000000",
  #       "stepSize" => "0.01000000"
  #     },
  #     %{
  #       "applyToMarket" => true,
  #       "avgPriceMins" => 5,
  #       "filterType" => "MIN_NOTIONAL",
  #       "minNotional" => "0.00100000"
  #     },
  #     %{"filterType" => "ICEBERG_PARTS", "limit" => 10},
  #     %{
  #       "filterType" => "MARKET_LOT_SIZE",
  #       "maxQty" => "1022300.00000000",
  #       "minQty" => "0.00000000",
  #       "stepSize" => "0.00000000"
  #     },
  #     %{"filterType" => "MAX_NUM_ALGO_ORDERS", "maxNumAlgoOrders" => 5}
  #   ],
  #   "icebergAllowed" => true,
  #   "isMarginTradingAllowed" => false,
  #   "isSpotTradingAllowed" => true,
  #   "orderTypes" => ["LIMIT", "LIMIT_MAKER", "MARKET", "STOP_LOSS_LIMIT",
  #    "TAKE_PROFIT_LIMIT"],
  #   "quoteAsset" => "BTC",
  #   "quotePrecision" => 8,
  #   "status" => "TRADING",
  #   "symbol" => "STRATBTC"
  # },

  def change do
    create table(:pairs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      # LTCBTC
      add(:symbol, :text)
      # uuid of LTC
      add(:base_asset_id, references(:balances, type: :uuid))
      # uuid of BTC
      add(:quote_asset_id, references(:balances, type: :uuid))
      # binance's status like "TRADING"
      add(:status, :string)

      # filters related stuff
      add(:min_price, :text)
      add(:max_price, :text)
      add(:tick_size, :text)
      add(:min_quantity, :text)
      add(:max_quantity, :text)
      add(:step_size, :text)

      timestamps()
    end
  end
end
