defmodule Hefty.TradeEvents do
  import Ecto.Query, only: [from: 2, select: 3, order_by: 2, limit: 2]

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

    from(te in Hefty.Repo.Binance.TradeEvent,
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
