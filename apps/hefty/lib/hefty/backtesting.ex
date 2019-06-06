defmodule Hefty.Backtesting do
  def kick_off_backtesting(symbol, from_date, to_date) do
    {:ok, pid} = Hefty.Streaming.Backtester.SimpleStreamer.start_link()

    Hefty.Streaming.Backtester.SimpleStreamer.start_streaming(
      pid,
      symbol,
      from_date,
      to_date
    )
  end
end
