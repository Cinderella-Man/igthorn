defmodule Hefty.Algos.NaiveTest do
  use ExUnit.Case
  doctest Hefty.Streaming.Backtester.SimpleStreamer

  require Logger

  alias Hefty.Streaming.Backtester.SimpleStreamer
  alias Hefty.Repo.Binance.TradeEvent
  alias Decimal, as: D

  test "Naive trader full trade(buy + sell) test" do

    symbol = "XRPUSDT"

    Logger.debug("Step 1 - Stop any trading - it will get reconfigured and started again")

    Hefty.turn_off_trading(symbol)

    Logger.debug("Step 2 - start BinanceMock process")

    Hefty.Exchanges.BinanceMock.start_link()

    Logger.debug("Step 3 - clear trade_events table")

    qry = "TRUNCATE TABLE trade_events"
    Ecto.Adapters.SQL.query!(Hefty.Repo, qry, [])

    Logger.debug("Step 4 - clear trade_events table")

    qry = "TRUNCATE TABLE orders CASCADE"
    Ecto.Adapters.SQL.query!(Hefty.Repo, qry, [])

    Logger.debug("Step 5 - configure naive trader for symbol")

    current_settings = Hefty.fetch_naive_trader_settings(symbol)

    changeset = Ecto.Changeset.change(current_settings, %{
      :profit_interval => "0.001",
      :buy_down_interval => "0.0025",
      :budget => "100.0"
    })

    case Hefty.Repo.update(changeset) do
      {:ok, struct} -> struct
      {:error, _changeset} -> throw("Unable to update naive trader setting for symbol '#{symbol}'")
    end

    # makes sure that it's updated before starting trading process
    :timer.sleep(10)

    Logger.debug("Step 6 - start trading processes")

    Hefty.turn_on_trading(symbol)
    :timer.sleep(30)

    Logger.debug("Step 7 - fill table with trade events that we will stream")

    event_1 = %TradeEvent{
      :event_type => "trade",
      :event_time => 1_560_941_210_010,
      :symbol => "XRPUSDT",
      :trade_id => 10_000_001,
      :price => "0.43183010",
      :quantity => "213.10000000",
      :buyer_order_id => 20_000_001,
      :seller_order_id => 20_000_002,
      :trade_time => 1_560_941_210_010,
      :buyer_market_maker => false
    }

    event_2 = %TradeEvent{
      :event_type => "trade",
      :event_time => 1_560_941_210_020,
      :symbol => "XRPUSDT",
      :trade_id => 10_000_002,
      :price => "0.43183020",
      :quantity => "56.10000000",
      :buyer_order_id => 20_000_003,
      :seller_order_id => 20_000_004,
      :trade_time => 1_560_941_210_020,
      :buyer_market_maker => false
    }

    event_3 = %TradeEvent{
      :event_type => "trade",
      :event_time => 1_560_941_210_030,
      :symbol => "XRPUSDT",
      :trade_id => 10_000_003,
      :price => "0.43183030",
      :quantity => "12.10000000",
      :buyer_order_id => 20_000_005,
      :seller_order_id => 20_000_006,
      :trade_time => 1_560_941_210_030,
      :buyer_market_maker => false
    }

    [event_1, event_2, event_3]
      |> Enum.map(&(Hefty.Repo.insert(&1)))

    Logger.debug("Step 8 - kick of streaming of trade events every 3 * 100ms")

    SimpleStreamer.start_streaming("XRPUSDT", "2019-06-19", "2019-06-19", 100)

    Logger.debug("Step 9 - let's allow the rest of the events to be broadcasted")

    :timer.sleep(500)

    result = Hefty.Orders.fetch_orders(symbol)

    assert length(result) == 1
    [order] = result

    assert D.cmp(D.new(order.price), D.new(event_1.price)) == :lt
  end
end
