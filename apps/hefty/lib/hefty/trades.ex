defmodule Hefty.Trades do
  require Logger

  import Ecto.Query, only: [from: 2]

  alias Decimal, as: D
  alias Hefty.Repo.Binance.Order

  defmodule Trade do
    defstruct symbol: nil,
              buy_price: nil,
              sell_price: nil,
              quantity: nil,
              state: nil,
              profit_usdt: nil,
              profit_percentage: nil
  end

  def fetch(offset, limit, symbol \\ "") do
    Logger.debug("Fetching trades(based on orders) for a symbol(#{symbol})")

    # todo: Fetch current prices here

    trade_ids =
      from(o in Order,
        select: o.trade_id,
        where: o.side == "BUY",
        order_by: [desc: o.time],
        limit: ^limit,
        offset: ^offset
      )
      |> Hefty.Repo.all()

    from(o in Order,
      where: o.trade_id in ^trade_ids,
      order_by: [desc: o.time]
    )
    |> Hefty.Repo.all()
    |> Enum.group_by(& &1.trade_id)
    |> Map.values()
    |> Enum.map(&sum_up_trade/1)
  end

  def count(symbol \\ "") do
    Logger.debug("Fetching count of trades(based on orders) for a symbol(#{symbol})")

    from(o in Order,
      where: o.side == "BUY",
      select: count("*"),
      limit: 1
    )
    |> Hefty.Repo.one()
  end

  # should get mapping of current prices
  def sum_up_trade([buy_order]) do
    %Trade{
      :symbol => buy_order.symbol,
      :buy_price => buy_order.price,
      :quantity => buy_order.original_quantity
    }
  end

  # Fix this - this is only for filled - otherwise it should use current price
  def sum_up_trade([%Order{:status => "FILLED"} = sell_order, buy_order]) do
    initial_state = sum_up_trade([buy_order])
    profit_usdt = Hefty.Algos.Naive.Leader.calculate_outcome(buy_order, sell_order)
    %{initial_state | :sell_price => sell_order.price, :profit_usdt => D.to_float(profit_usdt)}
  end
end
