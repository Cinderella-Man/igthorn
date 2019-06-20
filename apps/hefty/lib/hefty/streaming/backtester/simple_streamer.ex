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
  defmodule State do
    defstruct db_streamer_task: nil,
              buy_stack: [],
              sell_stack: []
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    {:ok, %State{}}
  end

  def start_streaming(pid, symbol, from, to, interval \\ 5) do
    GenServer.cast(pid, {:start_streaming, symbol, from, to, interval})
  end

  def handle_cast({:start_streaming, symbol, from, to, interval}, state) do
    task = DbStreamer.start_link(symbol, from, to, self(), interval)
    {:noreply, %{ state | :db_streamer_task => task }}
  end

  @doc """
  Trade events coming from either db streamer
  """
  def handle_cast({:trade_event, trade_event}, state) do
    UiWeb.Endpoint.broadcast_from(
      self(),
      "stream-#{trade_event.symbol}",
      "trade_event",
      trade_event
    )

    {:noreply, state}
  end

  @doc """
  This handle is used to notify test that all events already arrived
  """
  def handle_cast(:stream_finished, state) do
    IO.puts("SimpleStream: Db stream finished")
    {:noreply, state}
  end

  @doc """
  Handles buy orders coming from Binance Mock
  """
  def handle_cast({:order, %Binance.OrderResponse{:side => "BUY"} = order}, state) do
    {:noreply, %{ state | :buy_stack => [order | state.buy_stack]}}
  end

  @doc """
  Handles sell orders coming from Binance Mock
  """
  def handle_cast({:order, %Binance.OrderResponse{:side => "SELL"} = order}, state) do
    {:noreply, %{ state | :sell_stack => [order | state.sell_stack]}}
  end
end
