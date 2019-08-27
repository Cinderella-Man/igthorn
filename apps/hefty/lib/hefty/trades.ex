defmodule Hefty.Trades do
  require Logger

  import Ecto.Query, only: [from: 2]

  alias Decimal, as: D
  alias Hefty.Repo.Trade
  alias Hefty.Repo.Binance.Order

  @fee D.new(Application.get_env(:hefty, :trading).defaults.fee)

  def fetch(offset, limit, symbol \\ "") do
    Logger.debug("Fetching trades for a symbol(#{symbol})")

    trades =
      from(t in Trade,
        where: like(t.symbol, ^"%#{String.upcase(symbol)}%"),
        order_by: [desc: t.sell_time],
        limit: ^limit,
        offset: ^offset
      )
      |> Hefty.Repo.all()

    symbols = trades |> Enum.map(& &1.symbol) |> Enum.group_by(& &1) |> Map.keys()

    current_prices = Hefty.TradeEvents.fetch_prices(symbols)

    trades
    |> update_profit(current_prices)
  end

  def count(symbol \\ "") do
    Logger.debug("Fetching count of trades for a symbol(#{symbol})")

    from(t in Trade,
      where: t.symbol == ^"%#{String.upcase(symbol)}%",
      select: count("*"),
      limit: 1
    )
    |> Hefty.Repo.one()
  end

  def fetch(id) do
    from(t in Hefty.Repo.Trade,
      where: t.id == ^id
    )
    |> Hefty.Repo.one()
  end

  @doc """
  This function is intended to be called after buy order was filled.
  It should NOT be called on buy order placed as there's no trade yet
  """
  def create_trade(%Order{
        :price => buy_price,
        :symbol => symbol,
        :original_quantity => quantity,
        :time => buy_time,
        :trade_id => id
      }) do
    %Hefty.Repo.Trade{
      :id => id,
      :symbol => symbol,
      :buy_price => buy_price,
      :quantity => quantity,
      :state => "SELL_PLACED",
      :buy_time => buy_time,
      :fee_rate => Application.get_env(:hefty, :trading).defaults.fee
    }
    |> Hefty.Repo.insert()
    |> elem(1)
  end

  @doc """
  This function is intended to be called after sell order was filled.
  It should NOT be called on sell order placed as there's no update yet
  """
  def update_trade(
        %Hefty.Repo.Trade{} = trade,
        buy_order,
        %Order{
          :price => sell_price,
          :time => sell_time
        } = sell_order
      ) do
    changeset =
      Ecto.Changeset.change(trade, %{
        :sell_price => sell_price,
        :sell_time => sell_time,
        :state => "COMPLETED",
        :profit_base_currency => calculate_profit(buy_order, sell_order) |> D.to_string(),
        :profit_percentage => calculate_profit_percentage(buy_order, sell_order) |> D.to_string()
      })

    case Hefty.Repo.update(changeset) do
      {:ok, struct} -> struct
      {:error, _changeset} -> throw("Unable to update trade")
    end
  end

  # Note: This will fail if we recalculate old prices using new settings for fee
  def calculate_profit(
        %Order{:price => buy_price, :original_quantity => quantity},
        %Order{:price => sell_price}
      ) do
    calculate_profit(buy_price, sell_price, quantity, @fee)
  end

  defp calculate_profit(buy_price, sell_price, quantity, fee) do
    gross_invested = calculate_total_invested(buy_price, quantity, fee)
    net_sale = calculate_net_sale_amount(sell_price, quantity, fee)

    D.sub(net_sale, gross_invested)
  end

  def calculate_profit_percentage(
        %Order{:price => buy_price, :original_quantity => quantity},
        %Order{:price => sell_price}
      ) do
    calculate_profit_percentage(buy_price, sell_price, quantity, @fee)
  end

  def calculate_profit_percentage(buy_price, sell_price, quantity, fee) do
    gross_invested = calculate_total_invested(buy_price, quantity, fee)
    profit = calculate_profit(buy_price, sell_price, quantity, fee)
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

  defp update_profit(
         %Trade{
           buy_price: buy_price,
           sell_price: nil,
           quantity: quantity,
           fee_rate: fee
         } = trade,
         current_prices
       ) do
    current_price = Map.get(current_prices, :price, 0)

    profit_base_currency = D.to_float(calculate_profit(buy_price, current_price, quantity, fee))

    profit_percentage =
      D.to_float(calculate_profit_percentage(buy_price, current_price, quantity, fee))

    %{
      trade
      | :profit_base_currency => profit_base_currency,
        :profit_percentage => profit_percentage
    }
  end

  defp update_profit(trade, _), do: trade

  @doc"""
  Counting gaining traders bu symbol between selling time
  """
  def count_gaining(symbol, from, to) do
    query =
      "SELECT COUNT(*) FROM trades " <>
      "WHERE symbol = '#{symbol}' " <>
      "AND sell_time >= #{from} AND " <>
      "sell_time < #{to} AND " <>
      "cast(profit_base_currency as double precision) > 0;"
    Ecto.Adapters.SQL.query!(Hefty.Repo, query, [])
  end

  @doc"""
  Counting losing traders bu symbol between selling time
  """
  def count_losing(symbol, from, to) do
    query =
      "SELECT COUNT(*) FROM trades " <>
      "WHERE symbol = '#{symbol}' " <>
      "AND sell_time >= #{from} AND " <>
      "sell_time < #{to} AND " <>
      "cast(profit_base_currency as double precision) < 0;"
    Ecto.Adapters.SQL.query!(Hefty.Repo, query, [])
  end

  def fetch_trading_symbols(from, to) do
    from(t in Trade,
      select: [t.symbol],
      where: t.sell_time >= ^from and t.sell_time < ^to,
      order_by: t.symbol,
      group_by: t.symbol
    )
    |> Hefty.Repo.all()
  end
end
