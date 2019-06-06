#! /usr/bin/env elixir
#
# A Template for writing an Elixir script by
# Andreas Altendorfer <andreas@altendorfer.at>
defmodule Shell do
  import Ecto.Query
  require Logger

  @columns (~w(event_type event_time symbol
  trade_id price quantity buyer_order_id
  seller_order_id trade_time buyer_market_maker))
  |> Enum.map(&(String.to_atom(&1)))

  alias Hefty.Repo.Binance.TradeEvent

  #
  # Add your script here
  #
  @opts [
    strict: [
      path: :string
    ],
    aliases: [
      p: :path
    ]
  ]

  #
  # Call your script here
  #
  def run({[{:path, path}], _}) do
    if (!File.exists?(path)) do
      throw "Unable to find file #{path}"
    end

    File.stream!(path)
      |> CSV.decode!(headers: true)
      |> Stream.map(&convert_to_row(&1))
      |> Stream.run

    "Finished successfully"
  end

  def convert_to_row(csv_line) do
    %TradeEvent{}
    |> Ecto.Changeset.cast(csv_line, @columns)
    |> Hefty.Repo.insert!
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
