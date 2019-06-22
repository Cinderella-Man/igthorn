defmodule Hefty do
  @moduledoc """
  Documentation for Hefty.

  Hefty comes from hft
  (high frequence trading)
  """

  import Ecto.Query, only: [from: 2]
  require Logger

  def fetch_stream_settings() do
    Logger.debug("Fetching streams' settings")

    query =
      from(ss in Hefty.Repo.StreamingSetting,
        order_by: [desc: ss.enabled, asc: ss.symbol]
      )

    Hefty.Repo.all(query)
  end

  def fetch_stream_settings(symbol) do
    Logger.debug("Fetching stream settings for a symbol", symbol: symbol)

    query =
      from(ss in Hefty.Repo.StreamingSetting,
        where: like(ss.symbol, ^"%#{symbol}%"),
        order_by: [desc: ss.enabled, asc: ss.symbol]
      )

    Hefty.Repo.all(query)
  end

  def fetch_tick(symbol) do
    Logger.debug("Fetching last tick for a symbol", symbol: symbol)

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
    Logger.debug("Fetching currently streaming symbols", symbol: symbol)
    symbols = Hefty.Streaming.Binance.Server.fetch_streaming_symbols()

    case symbol != "" do
      false ->
        symbols

      _ ->
        symbols
        |> Enum.filter(fn {s, _} -> String.contains?(String.upcase(s), symbol) end)
    end
  end

  @spec flip_streamer(String.t()) :: :ok
  def flip_streamer(symbol) when is_binary(symbol) do
    Logger.info("Flip streaming for a symbol #{symbol}")
    Hefty.Streaming.Binance.Server.flip_stream(symbol)
  end

  @spec flip_trading(String.t()) :: :ok
  def flip_trading(symbol) when is_binary(symbol) do
    Logger.info("Flip trading for a symbol #{symbol}")
    Hefty.Algo.Naive.flip_trading(symbol)
  end

  @spec turn_off_trading(String.t()) :: :ok
  def turn_off_trading(symbol) when is_binary(symbol) do
    Logger.info("Turn off trading for a symbol #{symbol}")
    Hefty.Algo.Naive.turn_off(symbol)
  end

  @spec turn_on_trading(String.t()) :: :ok
  def turn_on_trading(symbol) when is_binary(symbol) do
    Logger.info("Turn on trading for a symbol #{symbol}")
    Hefty.Algo.Naive.turn_on(symbol)
  end

  def fetch_symbols() do
    query =
      from(p in Hefty.Repo.Binance.Pair,
        select: %{symbol: p.symbol},
        order_by: p.symbol
      )

    Hefty.Repo.all(query)
  end

  def fetch_naive_trader_settings() do
    query =
      from(nts in Hefty.Repo.NaiveTraderSetting,
        order_by: nts.symbol
      )

    Hefty.Repo.all(query)
  end

  def fetch_naive_trader_settings(offset, limit, symbol \\ "") do
    from(nts in Hefty.Repo.NaiveTraderSetting,
      order_by: nts.symbol,
      where: like(nts.symbol, ^"%#{String.upcase(symbol)}%"),
      limit: ^limit,
      offset: ^offset
    )
    |> Hefty.Repo.all()
  end

  @spec count_naive_trader_settings :: number()
  def count_naive_trader_settings(symbol \\ "") do
    from(nts in Hefty.Repo.NaiveTraderSetting,
      select: count("*"),
      where: like(nts.symbol, ^"%#{String.upcase(symbol)}%")
    )
    |> Hefty.Repo.one()
  end

  def update_naive_trader_settings(data) do
    record = Hefty.Repo.get_by!(Hefty.Repo.NaiveTraderSetting, symbol: data["symbol"])

    nts =
      Ecto.Changeset.change(
        record,
        %{
          :budget => data["budget"],
          :buy_down_interval => data["buy_down_interval"],
          :chunks => String.to_integer(data["chunks"]),
          :profit_interval => data["profit_interval"],
          :stop_loss_interval => data["stop_loss_interval"],
          :trading => String.to_existing_atom(data["trading"])
        }
      )

    case Hefty.Repo.update(nts) do
      {:ok, struct} ->
        struct

      {:error, _changeset} ->
        throw("Unable to update " <> data["symbol"] <> " naive trader settings")
    end
  end

end
