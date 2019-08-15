defmodule Hefty.Pairs do
  require Logger

  import Ecto.Query, only: [from: 2]

  def fetch_symbols() do
    from(p in Hefty.Repo.Binance.Pair,
      select: %{symbol: p.symbol},
      order_by: p.symbol
    )
    |> Hefty.Repo.all()
  end
end
