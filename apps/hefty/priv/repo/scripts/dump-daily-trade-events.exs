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
  require Logger

  @columns ~w( event_type event_time symbol
  trade_id price quantity buyer_order_id
  seller_order_id trade_time buyer_market_maker)

  #
  # Add your script here
  #
  @opts [
    strict: [
      date: :string
    ],
    aliases: [
      d: :date
    ]
  ]

  #
  # Call your script here
  #
  def run({[{:date, date}], _}) do
    files = (
      from te in Hefty.Repo.Binance.TradeEvent,
      group_by: te.symbol,
      select: {te.symbol, count(te.id)}
    )
    |> Hefty.Repo.stream
    |> Flow.from_enumerable(max_demand: 1)
    |> Flow.partition
    |> Flow.map(
      &(stream_data_by_symbol(elem(&1, 0), date))
    )
    |> Enum.to_list()
    IO.inspect(files)

    # Logger.info("Data stored to files: #{Enum.join(files, "\n")}")
  end

  def stream_data_by_symbol(symbol, date) do
    file = "#{date}-#{symbol}.csv"
    Logger.info(
      "Saving data from #{date} for #{symbol} into #{file}"
    )
    Hefty.Repo.transaction fn ->
      symbol
        |> build_query(date)
        |> Hefty.Repo.stream
        |> Stream.map(&(convert_to_csv_line(&1)))
        |> (fn lines -> Stream.concat(@columns, lines) end).()
        |> CSV.encode()
        |> Stream.map(
          &(Enum.into(&1, File.stream!(file)))
        )
      file
    end
  end

  def build_query(symbol, date) do
    from_datetime = NaiveDateTime.from_iso8601!("#{date}T00:00:00.000Z")
    from_timestamp = from_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix

    to_datetime = NaiveDateTime.add(from_datetime, 24 * 60 * 60, :second)
    to_timestamp = to_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix

    from te in Hefty.Repo.Binance.TradeEvent,
      where: te.trade_time >= ^(from_timestamp * 1000),
      where: te.trade_time < ^(to_timestamp * 1000),
      where: te.symbol == ^symbol
  end

  defp convert_to_csv_line(record) do
    Enum.map(@columns, &Map.get(record, &1))
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
