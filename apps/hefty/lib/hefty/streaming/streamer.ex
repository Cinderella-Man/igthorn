defmodule Hefty.Streaming.Streamer do
  use WebSockex

  require Logger

  defmodule State do
    defstruct symbol: nil, subscribers: []
  end

  def start_link(symbol) do
    symbol = String.downcase(symbol)
    Logger.debug("Starting streaming on #{symbol}")
    Logger.debug("wss://stream.binance.com:9443/ws/#{symbol}@trade")

    WebSockex.start_link(
      "wss://stream.binance.com:9443/ws/#{symbol}@trade",
      __MODULE__,
      %State{
        :symbol => symbol
      },
      name: :"#{__MODULE__}-#{symbol}"
    )
  end

  def subscribe(stream_pid, pid \\ self()) do
    Logger.debug("Subscribing to pid", pid: pid)
    GenServer.cast(stream_pid, {:subscribe, pid})
  end

  @doc """
  This function will be used to handle incoming trade events.

  Two things needs  to happen:
  - store trade event
  - inform interested parties about event
  """
  def handle_frame({:text, msg}, state) do
    Logger.debug("Frame received")

    case JSON.decode(msg) do
      {:ok, event} -> handle_event(event, state)
      _ -> throw("Unable to parse: " <> msg)
    end
  end

  # Custom protocol as websocketx is NOT using GenServer...
  def handle_info({:"$gen_cast", {:subscribe, pid}}, state) do
    Logger.debug("Subscribe called with pid", pid: pid)
    Process.monitor(pid)
    # {:ok, new_state} is expected as websocketx is NOT using GenServer... 
    {:ok, %{state | :subscribers => [pid | state.subscribers]}}
  end

  def handle_info({:DOWN, _ref, pid, _reason}, state) do
    {:ok, %{state | :subscribers => List.delete(state.subscribers, pid)}}
  end

  defp handle_event(%{"e" => "trade"} = event, state) do
    Logger.debug("Getting event - #{event["symbol"]}")

    {:ok, trade_event} =
      %Hefty.Repo.Binance.TradeEvent{
        :event_type => event["e"],
        :event_time => event["E"],
        :symbol => event["s"],
        :trade_id => event["t"],
        :price => event["p"],
        :quantity => event["q"],
        :buyer_order_id => event["b"],
        :seller_order_id => event["a"],
        :trade_time => event["T"],
        :buyer_market_maker => event["m"]
      }
      |> Hefty.Repo.insert()

    IO.inspect(state.subscribers)

    state.subscribers
    |> Enum.map(&(send(&1, {:trade_event, trade_event})))

    {:ok, state}
  end
end
