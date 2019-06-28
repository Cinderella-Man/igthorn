defmodule Hefty.Streaming.Backtester.SimpleStreamer do
  use GenServer

  alias Hefty.Streaming.Backtester.DbStreamer

  alias Decimal, as: D

  require Logger

  @moduledoc """
  The SimpleStreamer module as the name implies is a responsible for
  streaming trade events of specified symbol between from date and
  to date from db.

  It expects to be given symbol, from date, to date and ms step.

  Server executes a query and gets a stream handle from db. It then
  fetches one row at the time and pushes it to `trade_events` PubSub
  that strategies are subscribed to (similar to what real Binance
  streamer is doing).

  As strategies are making orders those are pushed to Binance client
  which is faked for backtesting and it just forwards those orders
  through "orders" PubSub channel back to SimpleStreamer.

  SimpleStreamer holds all orders in state inside "temp_stack" list
  which contains all orders until trade event's price won't "beat"
  order which then automatically is pushed out as trade event simulating
  this way an fulfilled order. This brings a single problem of
  trade event that already got pulled out from stream - it needs to
  be put on top of stack and taken out in next iteration.
  """
  defmodule State do
    defstruct db_streamer_task: nil,
              buy_stack: [],
              sell_stack: []
  end

  def start_link(_args \\ nil) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, %State{}}
  end

  def start_streaming(symbol, from, to, interval \\ 5) do
    GenServer.cast(__MODULE__, {:start_streaming, symbol, from, to, interval})
  end

  def add_order(%Binance.OrderResponse{} = order) do
    GenServer.cast(__MODULE__, {:order, order})
  end

  def handle_cast({:start_streaming, symbol, from, to, interval}, state) do
    task = DbStreamer.start_link(symbol, from, to, self(), interval)
    {:noreply, %{state | :db_streamer_task => task}}
  end

  # CALLBACKS

  @doc """
  Trade events coming from db streamer

  Simplest case - no hanging orders
  """
  def handle_cast(
        {:trade_event, trade_event},
        %State{:buy_stack => [], :sell_stack => []} = state
      ) do
    broadcast_trade_event(trade_event)
    {:noreply, state}
  end

  def handle_cast(
        {:trade_event, trade_event},
        %State{:buy_stack => buy_stack, :sell_stack => sell_stack} = state
      ) do
    lt = &less_than/2
    gt = &greather_than/2

    buy_stack
    |> Enum.take_while(&compare_string_prices(trade_event.price, &1.price, lt))
    |> Enum.map(&convert_order_to_event(&1, trade_event.event_time))
    |> Enum.map(&broadcast_trade_event(&1))

    sell_stack
    |> Enum.take_while(&compare_string_prices(trade_event.price, &1.price, gt))
    |> Enum.map(&convert_order_to_event(&1, trade_event.event_time))
    |> Enum.map(&broadcast_trade_event(&1))

    new_buy_stack =
      buy_stack
      |> Enum.drop_while(&compare_string_prices(trade_event.price, &1.price, lt))

    new_sell_stack =
      sell_stack
      |> Enum.drop_while(&compare_string_prices(trade_event.price, &1.price, gt))

    broadcast_trade_event(trade_event)

    {:noreply, %{state | :buy_stack => new_buy_stack, :sell_stack => new_sell_stack}}
  end

  @doc """
  This handle is used to notify test that all events already arrived
  """
  def handle_cast(:stream_finished, state) do
    Logger.info("Db stream has finished")
    {:noreply, state}
  end

  @doc """
  Handles buy orders coming from Binance Mock
  """
  def handle_cast({:order, %Binance.OrderResponse{:side => "BUY"} = order}, state) do
    {:noreply,
     %{state | :buy_stack => [order | state.buy_stack] |> Enum.sort(&(&1.price > &2.price))}}
  end

  @doc """
  Handles sell orders coming from Binance Mock
  """
  def handle_cast({:order, %Binance.OrderResponse{:side => "SELL"} = order}, state) do
    {:noreply,
     %{state | :sell_stack => [order | state.sell_stack] |> Enum.sort(&(&1.price < &2.price))}}
  end

  # PRIVATE FUNCTIONS

  defp broadcast_trade_event(event) do
    # Logger.debug("Streaming trade event #{event.trade_id} for symbol #{event.symbol}")

    UiWeb.Endpoint.broadcast_from(
      self(),
      "stream-#{event.symbol}",
      "trade_event",
      event
    )
  end

  defp convert_order_to_event(%Binance.OrderResponse{} = order, time) do
    %Hefty.Repo.Binance.TradeEvent{
      :event_type => order.type,
      :event_time => time - 1,
      :symbol => order.symbol,
      :trade_id => "fake-#{time}",
      :price => order.price,
      :quantity => order.orig_qty,
      # hack - it does not matter
      :buyer_order_id => order.order_id,
      # hack - it does not matter
      :seller_order_id => order.order_id,
      :trade_time => time - 1,
      :buyer_market_maker => false
    }
  end

  defp compare_string_prices(a, b, predicate) do
    predicate.(D.new(a), D.new(b))
  end

  defp less_than(a, b) do
    D.cmp(a, b) == :lt
  end

  defp greather_than(a, b) do
    D.cmp(a, b) == :gt
  end
end
