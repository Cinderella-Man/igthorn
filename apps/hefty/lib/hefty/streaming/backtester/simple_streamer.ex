defmodule Hefty.Streaming.Backtester.SimpleStreamer do
  use GenServer

  alias Hefty.Streaming.Backtester.DbStreamer

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

  def start_link() do
    GenServer.start_link(__MODULE__, [self()])
  end

  def init([backtesting_pid]) do
    {:ok, %{backtesting_pid: backtesting_pid}}
  end

  def start_streaming(pid, symbol, from, to, interval \\ 5) do
    GenServer.cast(pid, {:start_streaming, symbol, from, to, interval})
  end

  def handle_cast({:start_streaming, symbol, from, to, interval}, state) do
    task = DbStreamer.start_link(symbol, from, to, self(), interval)
    {:noreply, Map.put(state, :db_streamer_task, task)}
  end

  @doc """
  Trade events coming from either db streamer
  """
  def handle_cast({:trade_event, trade_event}, state) do
    IO.inspect(trade_event)
    {:noreply, state}
  end

  @doc """
  This handle is used to notify test that all events already arrived
  """
  def handle_cast(:stream_finished, state) do
    send(state.backtesting_pid, :stream_finished)
  end

  @doc """
  Those should be coming from Binance Mock
  """
  def handle_cast({:order, order}, state) do
    {:noreply, Map.get_and_update(state, :temp_stack, fn stack -> [order | stack] end)}
  end
end