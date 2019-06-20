defmodule Hefty.Streaming.Backtester.SimpleStreamerTest do
  use ExUnit.Case
  doctest Hefty.Streaming.Backtester.SimpleStreamer

  alias Hefty.Streaming.Backtester.SimpleStreamer
  alias Hefty.Repo.Binance.TradeEvent
  alias Hefty.Streaming.Backtester.DummyListener

  test "dummy" do
    qry = "TRUNCATE TABLE trade_events"
    Ecto.Adapters.SQL.query!(Hefty.Repo, qry, [])

    Hefty.turn_off_trading("XRPUSDT")

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

    [event_1, event_2, event_3] =
      [event_1, event_2, event_3]
      |> Enum.map(&(Hefty.Repo.insert(&1) |> elem(1)))

    # start listening to
    {:ok, listener_pid} = DummyListener.start_link("XRPUSDT")

    # This will kick of streaming
    SimpleStreamer.start_streaming("XRPUSDT", "2019-06-19", "2019-06-19", 1000)

    # let's put order after first event
    :timer.sleep(1100)

    fake_order = %Binance.OrderResponse{
      :client_order_id => "fake-doesnt-matter",
      :executed_qty => "0.00000000",
      :order_id => 50_000_001,
      :orig_qty => "123.72000000",
      :price => "0.43183025",
      :side => "BUY",
      :status => "NEW",
      :symbol => "XRPUSDT",
      :time_in_force => "GTC",
      :transact_time => 1_560_941_210_025,
      :type => "LIMIT"
    }

    SimpleStreamer.add_order(fake_order)

    # let's allow the rest of the events to be broadcasted
    :timer.sleep(3200)

    # retrieve all streamed events from dummy listener

    streamed_events = DummyListener.fetch_streamed(listener_pid)

    # house keeping - this is how event should look like based on our fake order
    expected_event = %TradeEvent{
      :event_type => fake_order.type,
      :event_time => event_3.trade_time - 1,
      :symbol => fake_order.symbol,
      :trade_id => "fake-#{event_3.trade_time}",
      :price => fake_order.price,
      :quantity => fake_order.orig_qty,
      :buyer_order_id => fake_order.order_id,
      :seller_order_id => fake_order.order_id,
      :trade_time => event_3.trade_time - 1,
      :buyer_market_maker => false
    }

    # fake order should come as 3rd element
    expected_sequence = [event_1, event_2, expected_event, event_3]
    assert expected_sequence == streamed_events
  end
end
