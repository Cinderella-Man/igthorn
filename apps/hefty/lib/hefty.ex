defmodule Hefty do
  @moduledoc """
  Documentation for Hefty.

  Hefty comes from hftb
  (high frequence trading backend)
  """

  import Ecto.Query, only: [from: 2]
  require Logger

  def fetch_stream_settings() do
    query =
      from(ss in Hefty.Repo.StreamingSetting,
        order_by: ss.symbol
      )

    Hefty.Repo.all(query)
  end

  def fetch_tick(symbol) do
    case from(te in Hefty.Repo.Binance.TradeEvent,
           order_by: [desc: te.trade_time],
           where: te.symbol == ^symbol,
           limit: 1
         )
         |> Hefty.Repo.one() do
      nil -> %{:symbol => symbol, :price => "Not available"}
      result -> result
    end
  end

  def fetch_streaming_symbols(symbol \\ "") do
    symbols = Hefty.Streaming.Server.fetch_streaming_symbols()

    case symbol != "" do
      false ->
        symbols

      _ ->
        symbols
        |> Enum.filter(fn {s, _} -> String.contains?(String.upcase(s), symbol) end)
    end
  end

  def flip_streamer(symbol) do
    Hefty.Streaming.Server.flip_stream(symbol)
  end

  def flip_trader(symbol) do
    # Hefty.Trading.Server.flip_trading(symbol)
    {:ok, symbol}
  end

  def fetch_naive_trader_settings() do
    query =
      from(nts in Hefty.Repo.NaiveTraderSetting,
        order_by: nts.symbol
      )

    Hefty.Repo.all(query)
  end

  def fetch_naive_trader_settings(offset, limit) do
    query =
      from(nts in Hefty.Repo.NaiveTraderSetting,
        order_by: nts.symbol,
        limit: ^limit,
        offset: ^offset
      )

    Hefty.Repo.all(query)
  end

  def fetch_symbols() do
    query =
      from(p in Hefty.Repo.Binance.Pair,
        select: %{symbol: p.symbol},
        order_by: p.symbol
      )

    Hefty.Repo.all(query)
  end
end
