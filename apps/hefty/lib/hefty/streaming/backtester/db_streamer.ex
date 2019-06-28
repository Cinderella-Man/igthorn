defmodule Hefty.Streaming.Backtester.DbStreamer do
  use Task

  import Ecto.Query, only: [from: 2]

  @doc """
  Expected args:
  * symbol: string
  * from: string (YYYY-MM-DD)
  * to: string (YYYY-MM-DD)
  * interval: number (of ms)
  """
  def start_link(symbol, from, to, streamer_pid, interval \\ 5) do
    Task.start_link(__MODULE__, :run, [symbol, from, to, streamer_pid, interval])
  end

  def run(symbol, from, to, streamer_pid, interval) do
    from_ts = Hefty.Utils.Date.ymdToTs(from)

    to_ts =
      to
      |> Hefty.Utils.Date.ymdToNaiveDate()
      |> NaiveDateTime.add(24 * 60 * 60, :second)
      |> Hefty.Utils.Date.naiveDateToTs()

    Hefty.Repo.transaction(fn ->
      from(te in Hefty.Repo.Binance.TradeEvent,
        where: te.symbol == ^symbol and te.trade_time >= ^from_ts and te.trade_time < ^to_ts
      )
      |> Hefty.Repo.stream()
      |> Enum.map(fn row ->
        :timer.sleep(interval)
        GenServer.cast(streamer_pid, {:trade_event, row})
      end)
    end, timeout: :infinity)

    GenServer.cast(streamer_pid, :stream_finished)
  end
end
