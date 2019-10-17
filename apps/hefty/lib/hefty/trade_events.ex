defmodule Hefty.TradeEvents do
  import Ecto.Query, only: [from: 2, select: 3, order_by: 2, limit: 2]

  alias Hefty.Repo.Binance.TradeEvent, as: RepoTradeEvent
  alias Timex, as: T

  def fetch_prices(symbols) do
    prices =
      symbols
      |> Enum.map(&fetch_price(&1))

    Enum.zip(symbols, prices)
    |> Enum.into(%{})
  end

  def fetch_price(symbol) when is_binary(symbol) do
    from(te in RepoTradeEvent,
      select: te.price,
      where: te.symbol == ^symbol,
      order_by: [desc: te.trade_time],
      limit: 1
    )
    |> Hefty.Repo.one()
  end

  # TODO - make unique time (group by time)
  def fetch_latest_prices(symbol) do
    timestamp =
      T.now()
      |> DateTime.to_unix

    target = (timestamp - (3600)) * 1000

    from(te in Hefty.Repo.Binance.TradeEvent,
      select: [te.price, te.trade_time],
      order_by: [desc: te.trade_time],
#      limit: 2000,
      where: te.symbol == ^symbol and te.trade_time > ^target
    )
    |> Hefty.Repo.all()
    |> Enum.map(fn [a, b] -> [a, T.format!(DateTime.from_unix!(b, :millisecond), "{h24}:{0m}:{0s}"), div(b, 5000)] end)
    |> Enum.group_by(fn [a, _, c] -> c end)
    |> Enum.map(fn {symbol, data} -> data end)
    |> Enum.map(&(List.first(&1)))
    |> Enum.map(fn [a, b, c] -> [a, b] end)
    |> Enum.sort(&(List.last(&1) >= List.last(&2)))
  end

  def count(symbol, from, to) do
    get_base_range_query(symbol, from, to)
    |> select([], count("*"))
    |> Hefty.Repo.one()
  end

  def max(symbol, from, to) do
    get_base_range_query(symbol, from, to)
    |> order_by(desc: :price)
    |> limit(1)
    |> Hefty.Repo.one()
  end

  def min(symbol, from, to) do
    get_base_range_query(symbol, from, to)
    |> order_by(asc: :price)
    |> limit(1)
    |> Hefty.Repo.one()
  end

  def first(symbol, from, to) do
    get_base_range_query(symbol, from, to)
    |> order_by(asc: :trade_time)
    |> limit(1)
    |> Hefty.Repo.one()
  end

  def last(symbol, from, to) do
    get_base_range_query(symbol, from, to)
    |> order_by(desc: :trade_time)
    |> limit(1)
    |> Hefty.Repo.one()
  end

  defp get_base_range_query(symbol, from, to) do
    {from_ts, to_ts} = ymd_to_timestamp_range(from, to)

    from(te in RepoTradeEvent,
      where: te.symbol == ^symbol and te.trade_time >= ^from_ts and te.trade_time < ^to_ts
    )
  end

  defp ymd_to_timestamp_range(from, to) do
    from_ts = Hefty.Utils.Date.ymdToTs(from)

    to_ts =
      to
      |> Hefty.Utils.Date.ymdToNaiveDate()
      |> NaiveDateTime.add(24 * 60 * 60, :second)
      |> Hefty.Utils.Date.naiveDateToTs()

    {from_ts, to_ts}
  end
end
