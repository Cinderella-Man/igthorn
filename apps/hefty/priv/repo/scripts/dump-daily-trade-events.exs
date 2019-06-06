#! /usr/bin/env elixir
#
# A Template for writing an Elixir script by
# Andreas Altendorfer <andreas@altendorfer.at>
# 
# This command line tool requires `psql` and
# utilises Postgres' COPY tool to export to
# CSV format
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
    timestamps = get_timestamps(date)

    from(te in Hefty.Repo.Binance.TradeEvent,
      group_by: te.symbol,
      select: {te.symbol, count(te.id)}
    )
    |> Hefty.Repo.all()
    |> Enum.map(&(create_query(&1, date, timestamps)))

    Logger.info("Data stored successfully to files")
  end

  def create_query({symbol, _}, date, [from, to]) do
    command = "PGPASSWORD=postgres psql -Upostgres -h localhost -dhefty_dev  -c \"\\copy " <>
      "(SELECT * FROM trade_events WHERE trade_time >= #{from} AND trade_time < #{to} AND symbol='#{symbol}') " <>
      "TO '/tmp/dumps/#{symbol}-#{date}.csv' (format csv, delimiter ';')\""
    IO.puts(command)
    :os.cmd(String.to_charlist(command))
  end

  def get_timestamps(date) do
    from_datetime = NaiveDateTime.from_iso8601!("#{date}T00:00:00.000Z")

    from_timestamp =
      from_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    to_datetime = NaiveDateTime.add(from_datetime, 24 * 60 * 60, :second)

    to_timestamp =
      to_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    [from_timestamp * 1000, to_timestamp * 1000]
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
