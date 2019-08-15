defmodule Hefty.Trades do
  require Logger

  import Ecto.Query, only: [from: 2]

  alias Decimal, as: D
  alias Hefty.Repo.Binance.Order

  @fee D.new(Application.get_env(:hefty, :trading).defaults.fee)

  defmodule Trade do
    defstruct id: nil,
              symbol: nil,
              buy_price: nil,
              sell_price: nil,
              quantity: nil,
              state: nil,
              profit_base_currency: nil,
              profit_percentage: nil
  end

  def fetch(offset, limit, symbol \\ "") do
    Logger.debug("Fetching trades(based on orders) for a symbol(#{symbol})")

    # todo: Fetch current prices here

    result =
      from(o in Order,
        select: [o.trade_id, o.symbol],
        where: o.side == "BUY",
        order_by: [desc: o.time],
        limit: ^limit,
        offset: ^offset
      )
      |> Hefty.Repo.all()

    trade_ids = result |> Enum.map(&Enum.at(&1, 0))
    symbols = result |> Enum.map(&Enum.at(&1, 1)) |> Enum.group_by(& &1) |> Map.keys()

    current_prices = Hefty.TradeEvents.fetch_prices(symbols)

    from(o in Order,
      where: o.trade_id in ^trade_ids,
      order_by: [desc: o.time]
    )
    |> Hefty.Repo.all()
    |> Enum.group_by(& &1.trade_id)
    |> Map.values()
    |> Enum.map(&sum_up_trade(&1, current_prices))
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

  # Note: This will fail if we recalculate old prices using new settings for fee
  def calculate_profit(
        %Order{:price => buy_price, :original_quantity => quantity},
        %Order{:price => sell_price}
      ) do
    gross_invested = calculate_total_invested(buy_price, quantity, @fee)
    net_sale = calculate_net_sale_amount(sell_price, quantity, @fee)

    D.sub(net_sale, gross_invested)
  end

  def calculate_profit_percentage(
        %Order{:price => buy_price, :original_quantity => quantity} = buy_order,
        %Order{} = sell_order
      ) do
    gross_invested = calculate_total_invested(buy_price, quantity, @fee)
    profit = calculate_profit(buy_order, sell_order)
    D.mult(D.div(profit, gross_invested), 100)
  end

  @doc """
  Calculated total invested amount including fee
  """
  def calculate_total_invested(buy_price, quantity, fee) do
    spent_without_fee = D.mult(D.new(buy_price), D.new(quantity))
    D.add(spent_without_fee, D.mult(spent_without_fee, fee))
  end

  @doc """
  Calculated total amount after sale substracting fee
  """
  def calculate_net_sale_amount(sell_price, quantity, fee) do
    sale_without_fee = D.mult(D.new(sell_price), D.new(quantity))
    D.sub(sale_without_fee, D.mult(sale_without_fee, fee))
  end

  # single buy order - trade depends on it's state
  defp sum_up_trade([buy_order], _current_prices) do
    state =
      if buy_order.status == "CANCELLED" do
        "CANCELLED"
      else
        "BUY PLACED"
      end

    %Trade{
      :id => buy_order.trade_id,
      :symbol => buy_order.symbol,
      :buy_price => buy_order.price,
      :quantity => buy_order.original_quantity,
      :state => state,
      :profit_base_currency => 0.0,
      :profit_percentage => 0.0
    }
  end

  # Possibilities here:
  # 1 BUY + 1 SELL
  # 1 BUY + 2 SELL (Stop loss)
  defp sum_up_trade([sell_order | _] = orders, current_prices) do
    buy_order = List.last(orders)

    initial_trade = sum_up_trade([buy_order], current_prices)

    state =
      if sell_order.status == "FILLED" do
        "COMPLETED"
      else
        "SELL PLACED"
      end

    profit_base_currency = D.to_float(calculate_profit(buy_order, sell_order))
    profit_percentage = D.to_float(calculate_profit_percentage(buy_order, sell_order))

    %{
      initial_trade
      | :sell_price => sell_order.price,
        :profit_base_currency => profit_base_currency,
        :profit_percentage => profit_percentage,
        :state => state
    }
  end
end
