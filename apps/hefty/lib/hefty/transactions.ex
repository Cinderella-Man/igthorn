defmodule Hefty.Transactions do
  import Ecto.Query, only: [from: 2]
  require Logger

  # Fixme
  def fetch_transactions(offset, limit, symbol \\ "") do
    Logger.debug("Fetching transactions for symbol(#{symbol})")

    from(o in Hefty.Repo.Transaction,
      order_by: [desc: o.inserted_at],
      # where: like(o.symbol, ^"%#{String.upcase(symbol)}%"),
      limit: ^limit,
      offset: ^offset
    )
    |> Hefty.Repo.all()
  end

  # Fixme
  def count_transactions(symbol \\ "") do
    Logger.debug("Fetching total number of transactions symbol(#{symbol})")

    from(o in Hefty.Repo.Transaction,
      # ,
      select: count("*")
      # where: like(o.symbol, ^"%#{String.upcase(symbol)}%")
    )
    |> Hefty.Repo.one()
  end
end
