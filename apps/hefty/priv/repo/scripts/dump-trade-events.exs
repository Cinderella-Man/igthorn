#!/usr/bin/env elixir
#
# A Template for writing an Elixir script to be used on the
# command-line.
#
# (c) 2019 by Andreas Altendorfer <andreas@altendorfer.at>
# License: Free to use without any warranty.
#
# Usage:
#   1. Add your command to strict and aliases on @opts
#   2. Implement your function (rename my_script() )
#   3. Call your script in `run()` (line 38)
#
defmodule Shell do

  import Ecto.Query

  #
  # Add your script here
  #
  @opts [
    strict: [
      date: :string,
      symbol: :string,
      file: :string
    ],
    aliases: [
      d: :date,
      s: :symbol,
      f: :file
    ]
  ]

  def headers() do
    [
      [
        "event_type",
        "event_time",
        "symbol",
        "trade_id",
        "price",
        "quantity",
        "buyer_order_id",
        "seller_order_id",
        "trade_time",
        "buyer_market_maker",
      ]
    ]
  end

  def fields(record) do
    [
      record.event_type,
      record.event_time,
      record.symbol,
      record.trade_id,
      record.price,
      record.quantity,
      record.buyer_order_id,
      record.seller_order_id,
      record.trade_time,
      record.buyer_market_maker,
    ]
  end

  #
  # Call your script here
  #
  def run({args, _}) do

    file = case Keyword.fetch(args, :file) do
      {:ok, v} -> v
      _ -> "dump.csv"
    end

    args
      |> build_query
      |> Hefty.Repo.all
      |> convert_to_csv
      |> Enum.into(File.stream!(file))

    "OK. CSV file called #{file}"
  end

  def build_query(keywords) do
    query = from te in Hefty.Repo.Binance.TradeEvent
    append_conditions(keywords, query)
  end

  defp append_conditions([{:symbol, value} | rest], query) do
    value = String.upcase(value)
    query = from te in query, where: te.symbol == ^value
    append_conditions(rest, query)
  end

  defp append_conditions([{:date, value} | rest], query) do
    from_datetime = NaiveDateTime.from_iso8601!("#{value}T00:00:00.000Z")
    from_timestamp = from_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix

    to_datetime = NaiveDateTime.add(from_datetime, 24 * 60 * 60, :second)
    to_timestamp = to_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix

    query = from te in query,
            where: te.trade_time >= ^(from_timestamp * 1000) and te.trade_time < ^(to_timestamp * 1000)

    append_conditions(rest, query)
  end

  defp append_conditions(_, query), do: query

  defp convert_to_csv(records) do
    headers()
      |> Stream.concat(records |> Stream.map(&(fields(&1))))
      |> CSV.encode()
  end

  def main(args) do
    OptionParser.parse!(args, @opts)
    |> run
  end
end

#
# MAIN
#
System.argv()
|> Shell.main()
|> IO.puts()
