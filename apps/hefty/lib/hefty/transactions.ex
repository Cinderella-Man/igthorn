defmodule Hefty.Transactions do
  import Ecto.Query, only: [from: 2]
  require Logger

  def fetch_transactions(offset, limit, symbol \\ "") do
    Logger.debug("Fetching transactions for a symbol", symbol: symbol)

    from(o in Hefty.Repo.Transaction,
      order_by: [desc: o.inserted_at],
      # where: like(o.symbol, ^"%#{String.upcase(symbol)}%"),
      limit: ^limit,
      offset: ^offset
    )
    |> Hefty.Repo.all()
  end

  def count_transactions(symbol \\ "") do
    from(o in Hefty.Repo.Transaction,
      select: count("*")#,
      # where: like(o.symbol, ^"%#{String.upcase(symbol)}%")
    )
    |> Hefty.Repo.one()
  end
end
