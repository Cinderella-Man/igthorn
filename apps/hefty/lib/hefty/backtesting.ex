defmodule Hefty.Backtesting do
  @moduledoc """
  From Wikipedia:
  ```
  Backtesting is a term used in modeling to refer to testing a predictive model on historical data. Backtesting is a type of retrodiction, and a special type of cross-validation applied to previous time period(s).
  ```


  """

  def kick_off_backtesting(symbol, from_date, to_date) do
    Hefty.Streaming.Backtester.SimpleStreamer.start_streaming(
      symbol,
      from_date,
      to_date
    )
  end
end
