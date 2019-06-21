defmodule Hefty.Orders do
  @moduledoc """
  Holds business logic oriented around Orders (public interface)
  """

  import Ecto.Query, only: [from: 2]
  require Logger

  @spec fetch_orders(String.t) :: [%Hefty.Repo.Binance.Order{}]
  def fetch_orders(symbol) do
    Logger.debug("Fetching orders for a symbol", symbol: symbol)

    (from(o in Hefty.Repo.Binance.Order,
      where: o.symbol == ^symbol
    ))
    |> Hefty.Repo.all()
  end
end
