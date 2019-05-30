defmodule Hefty.Streaming.Backtester.SimpleStreamer do
  use GenServer

  import Ecto.Query, only: [from: 2]

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
    defstruct(interval: nil, db_stream: nil, temp_stack: [])
  end

  @doc """
  Expected args:
  * symbol: string
  * from: string (YYYY-MM-DD)
  * to: string (YYYY-MM-DD)
  * interval: number (of ms)
  """
  def start_link(symbol, from, to, interval \\ 5) do
    GenServer.start_link(__MODULE__, [symbol, from, to, interval],
      name: :"#{__MODULE__}-#{symbol}"
    )
  end

  def init([symbol, from, to, interval]) do
    GenServer.cast(:"#{__MODULE__}-#{symbol}", {:init_stream, symbol, from, to})

    {:ok,
     %State{
       :interval => interval
     }}
  end

  def handle_cast({:init_stream, symbol, from, to}, state) do
    from_ts = Hefty.Utils.Date.ymdToTs(from)

    to_ts = to
    |> Hefty.Utils.Date.ymdToNaiveDate
    |> NaiveDateTime.add(24 * 60 * 60, :second)
    |> Hefty.Utils.Date.naiveDateToTs

    {:ok, db_stream} =
      Hefty.Repo.transaction(fn ->
        from(te in Hefty.Repo.Binance.TradeEvent,
          where: te.symbol == ^symbol and te.trade_time >= ^from_ts and te.trade_time < ^to_ts
        )
        |> Hefty.Repo.stream()
      end)

    Process.send_after(self(), :next, state.interval)

    {:noreply, %{state | :db_stream => db_stream}}
  end

  def handle_cast({:order, order}, state) do
    {:noreply, Map.get_and_update(state, :temp_stack, fn stack -> [order | stack] end)}
  end

@doc """
Called by :init_stream as well as itself recursively
Publishes single trade event
"""
  def handle_info(:next, state) do
    [next] = Enum.to_list(state.db_stream |> Stream.take(1))
    IO.inspect(next)
    {:noreply, state}
  end
end
