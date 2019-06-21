defmodule Hefty.Streaming.Backtester.DummyListener do
  use GenServer

  def start_link(symbol) do
    GenServer.start_link(__MODULE__, symbol)
  end

  def init(symbol) do
    UiWeb.Endpoint.subscribe("stream-#{symbol}")
    {:ok, []}
  end

  def handle_info(%{event: "trade_event", payload: event}, state) do
    {:noreply, [event | state]}
  end

  def fetch_streamed(pid) do
    GenServer.call(pid, :fetch_streamed)
  end

  def handle_call(:fetch_streamed, _from, state) do
    {:reply, Enum.reverse(state), state}
  end
end
