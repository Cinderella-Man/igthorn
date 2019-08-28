defmodule Hefty.Streaming.Backtester.SimpleStreamer do
  use GenServer

  alias Hefty.Streaming.Backtester.DbStreamer

  alias Decimal, as: D

  require Logger

  @log_counter_every 5000

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
              buy_stacks: %{},
              sell_stacks: %{},
              events_counter: 0
  end

  def start_link(_args \\ nil) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, %State{}}
  end

  def start_streaming(symbol, from, to, interval \\ 2) do
    GenServer.cast(__MODULE__, {:start_streaming, symbol, from, to, interval})
  end

  def add_order(%Binance.OrderResponse{} = order) do
    GenServer.cast(__MODULE__, {:order, order})
  end

  def cleanup() do
    GenServer.cast(__MODULE__, :cleanup)
  end

  # CALLBACKS

  def handle_cast({:start_streaming, symbol, from, to, interval}, state) do
    task = DbStreamer.start_link(symbol, from, to, self(), interval)
    {:noreply, %{state | :db_streamer_task => task, :events_counter => 0}}
  end

  def handle_cast(
        {:trade_event, trade_event},
        %State{
          :buy_stacks => buy_stacks,
          :sell_stacks => sell_stacks,
          :events_counter => events_counter
        } = state
      ) do
    lt = &less_than/2
    gt = &greather_than/2

    buy_stacks
    |> Map.get(trade_event.symbol, [])
    |> Enum.take_while(&compare_string_prices(trade_event.price, &1.price, lt))
    |> Enum.map(&convert_order_to_event(&1, trade_event.event_time))
    |> Enum.map(&broadcast_trade_event(&1))

    sell_stacks
    |> Map.get(trade_event.symbol, [])
    |> Enum.take_while(&compare_string_prices(trade_event.price, &1.price, gt))
    |> Enum.map(&convert_order_to_event(&1, trade_event.event_time, trade_event.price))
    |> Enum.map(&broadcast_trade_event(&1))

    buy_orders =
      buy_stacks
      |> Map.get(trade_event.symbol, [])
      |> Enum.drop_while(&compare_string_prices(trade_event.price, &1.price, lt))

    sell_orders =
      sell_stacks
      |> Map.get(trade_event.symbol, [])
      |> Enum.drop_while(&compare_string_prices(trade_event.price, &1.price, gt))

    broadcast_trade_event(trade_event)
    events_counter = events_counter + 1

    if rem(events_counter, @log_counter_every) == 0 do
      Logger.info("#{events_counter} events published")
    end

    {:noreply,
     %{
       state
       | :buy_stacks => Map.put(buy_stacks, trade_event.symbol, buy_orders),
         :sell_stacks => Map.put(sell_stacks, trade_event.symbol, sell_orders),
         :events_counter => events_counter
     }}
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
  def handle_cast(
        {
          :order,
          %Binance.OrderResponse{:symbol => symbol, :side => "BUY"} = order
        },
        %State{
          :buy_stacks => buy_stacks
        } = state
      ) do
    current_orders = Map.get(buy_stacks, symbol, [])
    new_orders = [order | current_orders] |> Enum.sort(&(&1.price > &2.price))
    {:noreply, %{state | :buy_stacks => Map.put(buy_stacks, symbol, new_orders)}}
  end

  @doc """
  Handles sell orders coming from Binance Mock
  """
  def handle_cast(
        {
          :order,
          %Binance.OrderResponse{:symbol => symbol, :side => "SELL"} = order
        },
        %State{
          :sell_stacks => sell_stacks
        } = state
      ) do
    current_orders = Map.get(sell_stacks, symbol, [])
    new_orders = [order | current_orders] |> Enum.sort(&(&1.price < &2.price))
    {:noreply, %{state | :sell_stacks => Map.put(sell_stacks, symbol, new_orders)}}
  end

  def handle_cast(:cleanup, _state) do
    Logger.debug("Cleaning state of simple streamer")
    {:noreply, %State{}}
  end

  # PRIVATE FUNCTIONS
  defp broadcast_trade_event(event) do
    UiWeb.Endpoint.broadcast_from(
      self(),
      "stream-#{event.symbol}",
      "trade_event",
      event
    )
  end

  defp convert_order_to_event(%Binance.OrderResponse{} = order, time, market_price \\ nil) do
    %Hefty.Repo.Binance.TradeEvent{
      :event_type => order.type,
      :event_time => time - 1,
      :symbol => order.symbol,
      :trade_id => "fake-#{time}",
      # handles market orders
      :price =>
        if order.price === "0.0" do
          market_price
        else
          order.price
        end,
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
