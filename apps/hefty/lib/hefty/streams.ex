defmodule Hefty.Streams do
  import Ecto.Query, only: [from: 2]
  require Logger

  def fetch_settings() do
    Logger.debug("Fetching streams' settings")

    query =
      from(ss in Hefty.Repo.StreamingSetting,
        order_by: [desc: ss.enabled, asc: ss.symbol]
      )

    Hefty.Repo.all(query)
  end

  def fetch_settings(symbol) do
    Logger.debug("Fetching stream settings for a symbol", symbol: symbol)

    from(ss in Hefty.Repo.StreamingSetting,
      where: like(ss.symbol, ^"%#{String.upcase(symbol)}%"),
      order_by: [desc: ss.enabled, asc: ss.symbol]
    )
    |> Hefty.Repo.all()
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
end
