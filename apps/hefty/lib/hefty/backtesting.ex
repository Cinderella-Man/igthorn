defmodule Hefty.Backtesting do
  @moduledoc """
  From Wikipedia:
  ```
  Backtesting is a term used in modeling to refer to testing a predictive model on historical data. Backtesting is a type of retrodiction, and a special type of cross-validation applied to previous time period(s).
  ```


  """

  def kick_off_backtesting(symbol, from_date, to_date) do
    total_events = Hefty.TradeEvents.count(symbol, from_date, to_date)
    min = Hefty.TradeEvents.min(symbol, from_date, to_date)
    max = Hefty.TradeEvents.min(symbol, from_date, to_date)
    first = Hefty.TradeEvents.min(symbol, from_date, to_date)
    last = Hefty.TradeEvents.min(symbol, from_date, to_date)

    Hefty.Streaming.Backtester.SimpleStreamer.start_streaming(
      symbol,
      from_date,
      to_date
    )

    %{
      :total_events => total_events,
      :min => min,
      :max => max,
      :first => first,
      :last => last
    }
  end
end
