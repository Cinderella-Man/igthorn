defmodule Hefty.Algos.NaiveTest do
  use ExUnit.Case, async: false
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
      :chunks => 5,
      :budget => "100.0"
    }

    events = [event_1 | _rest] = getTestEvents()

    stream_events(symbol, settings, events)

    orders = Hefty.Orders.fetch_orders(symbol)

    [%{:state => %{:budget => budget}}] = Hefty.Algos.Naive.Leader.fetch_traders(symbol)

    assert length(orders) == 3
    [buy_order, sell_order, _new_buy_order] = orders

    # Making sure that budget is increased after sale
    assert D.cmp(budget, D.new("20.0")) == :gt

    assert D.cmp(D.new(buy_order.price), D.new(event_1.price)) == :lt

    assert D.cmp(
             D.new(buy_order.original_quantity),
             D.div(D.new(settings.budget), D.new(buy_order.price))
           ) == :lt

    assert buy_order.original_quantity == sell_order.original_quantity
  end

  test "Naive trader partial trade(buy) and pick up and (sell) test (abnormal trader exit)" do
    symbol = "XRPUSDT"

    settings = %{
      :profit_interval => "0.001",
      :buy_down_interval => "0.0025",
      :budget => "100.0"
    }

    setup_trading_environment(symbol, settings)

    Logger.debug("Step 7 - fill table with trade events that we will stream")

    [event_1 | _] = sample_events = getTestEvents()

    sample_events
    |> Enum.take(5)
    |> Enum.map(&Hefty.Repo.insert(&1))

    Logger.debug("Step 8 - kick of streaming of trade events every 100ms")

    SimpleStreamer.start_streaming("XRPUSDT", "2019-06-19", "2019-06-19", 100)

    Logger.debug("Step 9 - let's allow the rest of the events to be broadcasted")

    # allow 5 events to be sent
    :timer.sleep(720)

    [%{:pid => pid}] = Hefty.Algos.Naive.Leader.fetch_traders(symbol)
    Process.exit(pid, :kill)

    :timer.sleep(100)

    qry = "TRUNCATE TABLE trade_events"
    Ecto.Adapters.SQL.query!(Hefty.Repo, qry, [])

    Enum.drop(sample_events, 5)
    |> Enum.map(&Hefty.Repo.insert(&1))

    simple_streamer_pid = Process.whereis(:"Elixir.Hefty.Streaming.Backtester.SimpleStreamer")

    Process.exit(simple_streamer_pid, :normal)

    SimpleStreamer.start_streaming("XRPUSDT", "2019-06-19", "2019-06-19", 100)

    # allow rest of events to be sent
    :timer.sleep(600)

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

    event_9 = %{event_1 | :price => "0.43205"}

    (events ++ [event_9])
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

    # event just shy of stop loss price
    event_6 = generate_event(6, "0.4221360", "875.23573000")
    # event at exact stop loss price
    event_7 = generate_event(7, "0.4221350", "346.12345000")
    # this one should trigger stop loss
    event_8 = generate_event(8, "0.4221340", "268.82738000")
    # this one should fill stop loss
    event_9 = generate_event(9, "0.4221330", "246.99738000")
    # just to kick off another buy order
    event_10 = generate_event(10, "0.4221320", "623.31331000")

    events = events_up_to_buy_fulfilled ++ [event_6, event_7, event_8, event_9, event_10]

    stream_events(symbol, settings, events)

    orders = Hefty.Orders.fetch_orders(symbol)

    assert length(orders) == 4

    [filled_buy, cancelled_sell, stop_loss, new_buy] = orders

    # Checking filled buy order
    assert filled_buy.executed_quantity == filled_buy.original_quantity
    assert filled_buy.status == "FILLED"

    # Checking cancelled order
    assert cancelled_sell.executed_quantity == "0.00000"
    assert cancelled_sell.status == "CANCELLED"

    # Checking stop loss order
    assert D.cmp(D.new(stop_loss.price), D.new("0.4221350")) == :lt
    assert stop_loss.status == "FILLED"

    # Checking new buy price
    assert D.cmp(D.new(new_buy.price), D.new(event_9.price)) == :lt
    assert new_buy.status == "NEW"
  end

  test "Naive trader retarget test" do
    symbol = "XRPUSDT"

    settings = %{
      :profit_interval => "0.001",
      :buy_down_interval => "0.0025",
      # effectively disable stop loss
      :stop_loss_interval => "0.2",
      # effectively disable rebuying
      :rebuy_interval => "0.2",
      # which means retarget every 0.1%
      :retarget_interval => "0.0050",
      :budget => "100.0"
    }

    sample_events = getTestEvents()

    [event_1, event_2, event_3, event_4] = Enum.take(sample_events, 4)

    # price increased by 0.001
    event_2 = %{event_2 | :price => "0.43226193010"}
    # exact retarget price
    event_3 = %{event_3 | :price => "0.432909675250"}
    # above retarget price
    event_3 = %{event_3 | :price => "0.433"}
    # another event to trigger new buy
    event_4 = %{event_4 | :price => "0.44"}

    events = [event_1, event_2, event_3, event_4]

    stream_events(symbol, settings, events)

    orders = Hefty.Orders.fetch_orders(symbol)

    assert length(orders) == 2

    [cancelled_buy, new_buy] = orders

    # Checking cancelled order
    assert cancelled_buy.executed_quantity == "0.00000"
    assert cancelled_buy.status == "CANCELLED"

    # Checking stop loss order
    assert new_buy.price == "0.4389"
    assert new_buy.status == "NEW"

    assert D.cmp(D.new(new_buy.original_quantity), D.new(cancelled_buy.original_quantity)) == :lt
  end

  test "Naive trader rebuy test" do
    symbol = "XRPUSDT"

    settings = %{
      :profit_interval => "0.001",
      :buy_down_interval => "0.0025",
      # effectively disable stop loss
      :stop_loss_interval => "0.2",
      # rebuy at 5% from first seen price
      :rebuy_interval => "0.0475",
      # effectively disable retargeting
      :retarget_interval => "0.2",
      :budget => "100.0"
    }

    sample_events = getTestEvents()

    [event_1, event_2, event_3, event_4, event_5, event_6] = Enum.take(sample_events, 6)

    # -4% - still above rebuy price
    event_3 = %{event_3 | :price => "0.4145568960"}
    # exact retarget price
    event_3 = %{event_3 | :price => "0.4102385950"}
    # another event to trigger retarget
    event_4 = %{event_4 | :price => "0.4102385940"}
    # first event received by second trader
    event_5 = %{event_5 | :price => "0.4102385930"}
    # event that will cause buy order to be created
    event_6 = %{event_6 | :price => "0.4102385920"}

    events = [event_1, event_2, event_3, event_4, event_5, event_6]

    stream_events(symbol, settings, events)

    orders = Hefty.Orders.fetch_orders(symbol)

    assert length(orders) == 3

    traders = Hefty.Algos.Naive.Leader.fetch_traders(symbol)

    assert length(traders) == 2

    [filled_buy, unfilled_sell, new_buy] = orders

    # Checking filled buy order
    assert filled_buy.executed_quantity == filled_buy.original_quantity
    assert filled_buy.status == "FILLED"

    # Checking un-filled sell order
    assert unfilled_sell.price == "0.43182"
    assert unfilled_sell.status == "NEW"
    assert unfilled_sell.executed_quantity == "0.00000"

    # Checking new buy order
    assert new_buy.price == "0.40921"
    assert new_buy.status == "NEW"
    assert new_buy.executed_quantity == "0.00000"
  end

  @tag :special
  test "Naive trader limits number of trader(using chunks) and honors that limit when rebuy is called" do
    symbol = "XRPUSDT"

    settings = %{
      :profit_interval => "0.001",
      :buy_down_interval => "0.0025",
      # effectively disable stop loss
      :stop_loss_interval => "0.9",
      # rebuy at 5% from first seen price
      :rebuy_interval => "0.0475",
      # effectively disable retargeting
      :retarget_interval => "0.2",
      :budget => "100.0"
    }

    # starting point
    event_1 = generate_event(1, "0.50", "12.35564")
    # - 5% - will fill first buy + put sell
    event_2 = generate_event(2, "0.475", "45.3567")
    event_3 = generate_event(3, "0.475", "345.563")
    # - 10% - will fill second buy + put sell
    event_4 = generate_event(4, "0.45125", "23.467")
    event_5 = generate_event(5, "0.45125", "46.86")
    # - 15% - will fill third buy + put sell
    event_6 = generate_event(6, "0.4286875", "37.234")
    event_7 = generate_event(7, "0.4286875", "753.324")
    # - 20%
    event_8 = generate_event(8, "0.407253125", "3523.4234")
    event_9 = generate_event(9, "0.407253125", "827.343")
    # - 25%
    event_10 = generate_event(10, "0.38689046875", "4345.23423")
    event_11 = generate_event(11, "0.38689046875", "56456.321")
    # - 30%
    event_12 = generate_event(12, "0.3675459453125", "354.4234")
    event_13 = generate_event(13, "0.3675459453125", "235436.23")

    events = [
      event_1,
      event_2,
      event_3,
      event_4,
      event_5,
      event_6,
      event_7,
      event_8,
      event_9,
      event_10,
      event_11,
      event_12,
      event_13
    ]

    stream_events(symbol, settings, events)

    orders = Hefty.Orders.fetch_orders(symbol)

    assert length(orders) == 10

    traders = Hefty.Algos.Naive.Leader.fetch_traders(symbol)

    assert length(traders) == 5

    expected_buy_prices = [
      "0.49875",
      "0.47381",
      "0.45012",
      "0.42761",
      "0.40623"
    ]

    orders
    |> Enum.take_every(2)
    |> (fn buy_orders -> [buy_orders, expected_buy_prices] end).()
    |> List.zip()
    |> Enum.each(fn {buy_order, expected_price} ->
      assert buy_order.executed_quantity == buy_order.original_quantity
      assert buy_order.status == "FILLED"
      assert buy_order.side == "BUY"
      assert buy_order.price == expected_price
    end)

    expected_sell_prices = [
      "0.49999",
      "0.47499",
      "0.45124",
      "0.42867",
      "0.40724"
    ]

    orders
    |> Enum.drop(1)
    |> Enum.take_every(2)
    |> (fn sell_orders -> [sell_orders, expected_sell_prices] end).()
    |> List.zip()
    |> Enum.each(fn {sell_order, expected_price} ->
      assert sell_order.executed_quantity == "0.00000"
      assert sell_order.status == "NEW"
      assert sell_order.side == "SELL"
      assert sell_order.price == expected_price
    end)
  end

  def getTestEvents() do
    [
      generate_event(1, "0.43183010", "213.10000000"),
      generate_event(2, "0.43183020", "56.10000000"),
      generate_event(3, "0.43183030", "12.10000000"),
      # event at expected buy price (0.43075)
      generate_event(4, "0.43075", "38.92000000"),
      # event below expected price
      # it should trigger fake fill of placed order
      generate_event(5, "0.43065", "126.53000000"),
      # event below expected price
      # from now on we should have sell order @ 0.43204
      generate_event(6, "0.43200", "26.18500000"),
      # event at exact expected price
      generate_event(7, "0.43204", "62.92640000"),
      # event above expected price
      # this one should push fake event to fulfil sell order
      generate_event(8, "0.43205", "345.14235000"),
      # event above expected price
      # this one should push fake event to fulfil sell order
      generate_event(9, "0.43210", "3201.86480000")
    ]
  end

  def setup_trading_environment(symbol, settings) do
    Logger.debug("Step 1 - Stop any trading - it will get reconfigured and started again")

    Hefty.turn_off_trading(symbol)

    Logger.debug("Step 2 - start BinanceMock process")

    Hefty.Exchanges.BinanceMock.start_link([])

    Logger.debug("Step 3 - reboot simple streamer")

    # this is required as simple streamer holds stacks
    # of buy and sell orders which will be persisted
    # between tests
    # pid = Process.whereis(:"Elixir.Hefty.Streaming.Backtester.SimpleStreamer")
    # Process.exit(pid, :kill)
    SimpleStreamer.cleanup()

    # IO.inspect(Process.is_alive?(pid))

    :timer.sleep(100)

    Logger.debug("Step 4 - clear trade_events table")

    qry = "TRUNCATE TABLE trade_events"
    Ecto.Adapters.SQL.query!(Hefty.Repo, qry, [])

    :timer.sleep(100)

    Logger.debug("Step 5 - clear orders table (cascade)")

    qry = "TRUNCATE TABLE orders CASCADE"
    Ecto.Adapters.SQL.query!(Hefty.Repo, qry, [])

    :timer.sleep(100)

    Logger.debug("Step 6 - configure naive trader for symbol")

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

    Logger.debug("Step 7 - start trading processes")

    Hefty.turn_on_trading(symbol)

    :timer.sleep(50)
  end

  def stream_events(symbol, settings, events) do
    setup_trading_environment(symbol, settings)

    Logger.debug("Step 8 - fill table with trade events that we will stream")

    events
    |> Enum.map(&Hefty.Repo.insert(&1))

    Logger.debug("Step 9 - kick of streaming of trade events every 100ms")

    SimpleStreamer.start_streaming("XRPUSDT", "2019-06-19", "2019-06-19", 100)

    Logger.debug("Step 10 - let's allow the rest of the events to be broadcasted")

    :timer.sleep((length(events) + 1) * 100)
  end

  defp generate_event(id, price, quantity) do
    %TradeEvent{
      :event_type => "trade",
      :event_time => 1_560_941_210_000 + id * 10,
      :symbol => "XRPUSDT",
      :trade_id => 10_000_000 + id * 10,
      :price => price,
      :quantity => quantity,
      :buyer_order_id => 20_000_000 + id * 10,
      :seller_order_id => 30_000_000 + id * 10,
      :trade_time => 1_560_941_210_000 + id * 10,
      :buyer_market_maker => false
    }
  end
end
