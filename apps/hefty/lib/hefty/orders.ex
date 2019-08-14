defmodule Hefty.Orders do
  @moduledoc """
  Holds business logic oriented around Orders (public interface)
  """

  import Ecto.Query, only: [from: 2]
  require Logger

  @spec fetch_orders(String.t()) :: [%Hefty.Repo.Binance.Order{}]
  def fetch_orders(symbol) do
    fetch_orders(0, 100_000, symbol)
  end

  def fetch_orders(offset, limit, symbol \\ "") do
    Logger.debug("Fetching orders for a symbol", symbol: symbol)

    from(o in Hefty.Repo.Binance.Order,
      order_by: [desc: o.inserted_at],
      where: like(o.symbol, ^"%#{String.upcase(symbol)}%"),
      limit: ^limit,
      offset: ^offset
    )
    |> Hefty.Repo.all()
  end

  def count_orders(symbol \\ "") do
    from(o in Hefty.Repo.Binance.Order,
      select: count("*"),
      where: like(o.symbol, ^"%#{String.upcase(symbol)}%")
    )
    |> Hefty.Repo.one()
  end
end
