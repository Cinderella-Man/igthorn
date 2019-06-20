defmodule Hefty.Backtesting do
  def kick_off_backtesting(symbol, from_date, to_date) do
    Hefty.Streaming.Backtester.SimpleStreamer.start_streaming(
      symbol,
      from_date,
      to_date
    )
  end
end
