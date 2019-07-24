defmodule Hefty.Algos.NaiveTest do
  use ExUnit.Case
  doctest Hefty.Streaming.Backtester.SimpleStreamer

  require Logger

  alias Hefty.Streaming.Backtester.SimpleStreamer
  alias Hefty.Repo.Binance.TradeEvent
  alias Decimal, as: D

  test "Naive trader full trade(buy + sell) test" do
    symbol = "XRPUSDT"

    settings = %{
      :profit_interval => "0.001",
      :buy_down_interval => "0.0025",
      :budget => "100.0"
    }

    events = [event_1 | _rest] = getTestEvents()

    stream_events(symbol, settings, events)

    result = Hefty.Orders.fetch_orders(symbol)

    assert length(result) == 3
    [buy_order, sell_order, _new_buy_order] = result

    assert D.cmp(D.new(buy_order.price), D.new(event_1.price)) == :lt

    assert D.cmp(
             D.new(buy_order.original_quantity),
             D.div(D.new(settings.budget), D.new(buy_order.price))
           ) == :lt

    assert buy_order.original_quantity == sell_order.original_quantity
  end

  # test "Naive trader partial trade(buy) and pick up and (sell) test (abnormal trader exit)" do
  #   symbol = "XRPUSDT"

  #   settings = %{
  #     :profit_interval => "0.001",
  #     :buy_down_interval => "0.0025",
  #     :budget => "100.0"
  #   }

  #   setup_trading_environment(symbol, settings)

  #   Logger.debug("Step 7 - fill table with trade events that we will stream")

  #   [event_1, event_2, event_3, event_4, event_5, event_6, event_7, event_8] = getTestEvents()

  #   [event_1, event_2, event_3, event_4, event_5]
  #   |> Enum.map(&Hefty.Repo.insert(&1))

  #   Logger.debug("Step 8 - kick of streaming of trade events every 100ms")

  #   SimpleStreamer.start_streaming("XRPUSDT", "2019-06-19", "2019-06-19", 100)

  #   Logger.debug("Step 9 - let's allow the rest of the events to be broadcasted")

  #   # allow 5 events to be sent 
  #   :timer.sleep(720)

  #   IO.inspect("Before killing")

  #   [{pid, _ref}] = Hefty.Algos.Naive.Leader.fetch_traders(symbol)
  #   Process.exit(pid, :kill)

  #   IO.inspect(pid, label: "Pid found")

  #   :timer.sleep(100)

  #   qry = "TRUNCATE TABLE trade_events"
  #   Ecto.Adapters.SQL.query!(Hefty.Repo, qry, [])

  #   [event_6, event_7, event_8]
  #   |> Enum.map(&Hefty.Repo.insert(&1))

  #   simple_streamer_pid = Process.whereis(:"Elixir.Hefty.Streaming.Backtester.SimpleStreamer")

  #   Process.exit(simple_streamer_pid, :normal)

  #   SimpleStreamer.start_streaming("XRPUSDT", "2019-06-19", "2019-06-19", 100)

  #   # allow rest of events to be sent 
  #   :timer.sleep(500)

  #   result = Hefty.Orders.fetch_orders(symbol)

  #   IO.inspect(result)

  #   assert length(result) == 3
  #   [buy_order, sell_order, _new_buy_order] = result

  #   assert D.cmp(D.new(buy_order.price), D.new(event_1.price)) == :lt

  #   assert D.cmp(
  #            D.new(buy_order.original_quantity),
  #            D.div(D.new(new_settings.budget), D.new(buy_order.price))
  #          ) == :lt

  #   assert buy_order.original_quantity == sell_order.original_quantity
  # end

  test "Naive trader partial trade(buy) and pick up and (sell) test (graceful flip)" do
    symbol = "XRPUSDT"

    settings = %{
      :profit_interval => "0.001",
      :buy_down_interval => "0.0025",
      :budget => "100.0"
    }

    setup_trading_environment(symbol, settings)

    Logger.debug("Step 7 - fill table with trade events that we will stream")

    [event_1 | _] = events = getTestEvents()

    events
    |> Enum.take(5)
    |> Enum.map(&Hefty.Repo.insert(&1))

    Logger.debug("Step 8 - kick of streaming of trade events every 100ms")

    SimpleStreamer.start_streaming("XRPUSDT", "2019-06-19", "2019-06-19", 100)

    Logger.debug("Step 9 - let's allow the rest of the events to be broadcasted")

    # allow 5 events to be sent 
    :timer.sleep(700)

    Hefty.turn_off_trading(symbol)

    :timer.sleep(300)

    qry = "TRUNCATE TABLE trade_events"
    Ecto.Adapters.SQL.query!(Hefty.Repo, qry, [])

    events
    |> Enum.drop(5)
    |> Enum.map(&Hefty.Repo.insert(&1))

    Hefty.turn_on_trading(symbol)

    :timer.sleep(300)

    SimpleStreamer.start_streaming("XRPUSDT", "2019-06-19", "2019-06-19", 100)

    # allow rest of events to be sent 
    :timer.sleep(400)

    result = Hefty.Orders.fetch_orders(symbol)

    assert length(result) == 3
    [buy_order, sell_order, _new_buy_order] = result

    assert D.cmp(D.new(buy_order.price), D.new(event_1.price)) == :lt

    assert D.cmp(
             D.new(buy_order.original_quantity),
             D.div(D.new(settings.budget), D.new(buy_order.price))
           ) == :lt

    assert buy_order.original_quantity == sell_order.original_quantity
  end

  test "Naive trader stop loss test" do
    symbol = "XRPUSDT"

    settings = %{
      :profit_interval => "0.001",
      :buy_down_interval => "0.0025",
      :stop_loss_interval => "0.02",
      # effectively disable rebuying
      :rebuy_interval => "0.2",
      :budget => "100.0"
    }

    sample_events = getTestEvents()

    events_up_to_buy_fulfilled = Enum.take(sample_events, 5)

    event_6 = %TradeEvent{
      :event_type => "trade",
      :event_time => 1_560_941_210_060,
      :symbol => "XRPUSDT",
      :trade_id => 10_000_006,
      # just shy of stop loss
      :price => "0.4221360",
      :quantity => "126.53000000",
      :buyer_order_id => 20_000_011,
      :seller_order_id => 20_000_012,
      :trade_time => 1_560_941_210_060,
      :buyer_market_maker => false
    }

    event_7 = %TradeEvent{
      :event_type => "trade",
      :event_time => 1_560_941_210_070,
      :symbol => "XRPUSDT",
      :trade_id => 10_000_007,
      # exact stop loss
      :price => "0.4221350",
      :quantity => "126.53000000",
      :buyer_order_id => 20_000_013,
      :seller_order_id => 20_000_014,
      :trade_time => 1_560_941_210_070,
      :buyer_market_maker => false
    }

    # this one should trigger stop loss
    event_8 = %TradeEvent{
      :event_type => "trade",
      :event_time => 1_560_941_210_080,
      :symbol => "XRPUSDT",
      :trade_id => 10_000_008,
      # below
      :price => "0.4221340",
      :quantity => "126.53000000",
      :buyer_order_id => 20_000_015,
      :seller_order_id => 20_000_016,
      :trade_time => 1_560_941_210_080,
      :buyer_market_maker => false
    }

    events = events_up_to_buy_fulfilled ++ [event_6, event_7, event_8]

    stream_events(symbol, settings, events)

    result = Hefty.Orders.fetch_orders(symbol)

    assert length(result) == 3

    # TODO!
  end

  def getTestEvents() do
    [
      %TradeEvent{
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
      },
      %TradeEvent{
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
      },
      %TradeEvent{
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
      },
      # event at expected buy price (0.43075)
      %TradeEvent{
        :event_type => "trade",
        :event_time => 1_560_941_210_040,
        :symbol => "XRPUSDT",
        :trade_id => 10_000_004,
        :price => "0.43075",
        :quantity => "38.92000000",
        :buyer_order_id => 20_000_007,
        :seller_order_id => 20_000_008,
        :trade_time => 1_560_941_210_040,
        :buyer_market_maker => false
      },
      # event below expected price
      # it should trigger fake fill of placed order
      %TradeEvent{
        :event_type => "trade",
        :event_time => 1_560_941_210_050,
        :symbol => "XRPUSDT",
        :trade_id => 10_000_005,
        :price => "0.43065",
        :quantity => "126.53000000",
        :buyer_order_id => 20_000_009,
        :seller_order_id => 20_000_010,
        :trade_time => 1_560_941_210_050,
        :buyer_market_maker => false
      },
      # from now on we should have sell order @ 0.43204
      %TradeEvent{
        :event_type => "trade",
        :event_time => 1_560_941_210_060,
        :symbol => "XRPUSDT",
        :trade_id => 10_000_006,
        # below
        :price => "0.43200",
        :quantity => "126.53000000",
        :buyer_order_id => 20_000_011,
        :seller_order_id => 20_000_012,
        :trade_time => 1_560_941_210_060,
        :buyer_market_maker => false
      },
      %TradeEvent{
        :event_type => "trade",
        :event_time => 1_560_941_210_070,
        :symbol => "XRPUSDT",
        :trade_id => 10_000_007,
        # exact
        :price => "0.43204",
        :quantity => "126.53000000",
        :buyer_order_id => 20_000_013,
        :seller_order_id => 20_000_014,
        :trade_time => 1_560_941_210_070,
        :buyer_market_maker => false
      },
      # this one should push fake event to fulfil sell order
      %TradeEvent{
        :event_type => "trade",
        :event_time => 1_560_941_210_080,
        :symbol => "XRPUSDT",
        :trade_id => 10_000_008,
        # above
        :price => "0.43205",
        :quantity => "126.53000000",
        :buyer_order_id => 20_000_015,
        :seller_order_id => 20_000_016,
        :trade_time => 1_560_941_210_080,
        :buyer_market_maker => false
      }
    ]
  end

  def setup_trading_environment(symbol, settings) do
    Logger.debug("Step 1 - Stop any trading - it will get reconfigured and started again")

    Hefty.turn_off_trading(symbol)

    Logger.debug("Step 2 - start BinanceMock process")

    Hefty.Exchanges.BinanceMock.start_link([])

    Logger.debug("Step 3 - clear trade_events table")

    qry = "TRUNCATE TABLE trade_events"
    Ecto.Adapters.SQL.query!(Hefty.Repo, qry, [])

    Logger.debug("Step 4 - clear orders table (cascade)")

    qry = "TRUNCATE TABLE orders CASCADE"
    Ecto.Adapters.SQL.query!(Hefty.Repo, qry, [])

    Logger.debug("Step 5 - configure naive trader for symbol")

    current_settings =
      Hefty.fetch_naive_trader_settings(0, 1, symbol)
      |> List.first()

    changeset = Ecto.Changeset.change(current_settings, settings)

    case Hefty.Repo.update(changeset) do
      {:ok, struct} ->
        struct

      {:error, _changeset} ->
        throw("Unable to update naive trader setting for symbol '#{symbol}'")
    end

    # makes sure that it's updated before starting trading process
    :timer.sleep(50)

    Logger.debug("Step 6 - start trading processes")

    Hefty.turn_on_trading(symbol)

    :timer.sleep(50)
  end

  def stream_events(symbol, settings, events) do
    setup_trading_environment(symbol, settings)

    Logger.debug("Step 7 - fill table with trade events that we will stream")

    events
    |> Enum.map(&Hefty.Repo.insert(&1))

    Logger.debug("Step 8 - kick of streaming of trade events every 100ms")

    SimpleStreamer.start_streaming("XRPUSDT", "2019-06-19", "2019-06-19", 120)

    Logger.debug("Step 9 - let's allow the rest of the events to be broadcasted")

    :timer.sleep((length(events) + 1) * 120)
  end
end
