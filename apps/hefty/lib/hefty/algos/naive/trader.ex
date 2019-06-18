defmodule Hefty.Algos.Naive.Trader do
  use GenServer
  require Logger
  import Ecto.Query, only: [from: 2]
  alias Decimal, as: D

  @binance_client Application.get_env(:hefty, :exchanges).binance

  @moduledoc """
  Hefty.Algos.Naive.Trader module is responsible for making a trade(buy + sell)
  on a single symbol.

  Naive trader is simple strategy which hopes that it will get on more raising
  waves than drops.

  Idea is based on "My Adventures in Automated Crypto Trading" presentation
  by Timothy Clayton @ https://youtu.be/b-8ciz6w9Xo?t=2297

  It requires few informations to work:
  - symbol
  - budget (amount of coins in "quote" currency)
  - profit interval (expected net profit in % - this will be used to set
  `sell orders` at level of `buy price`+`buy_fee`+`sell_fee`+`expected profit`)
  - buy down interval (expected buy price in % under current value)
  - chunks (split of budget to transactions - for example 5 represents
  up 5 transactions at the time - none of them will be more than 20%
  of budget*)
  - stop loss interval (defines % of value that stop loss order will be at)

  NaiveTrader implements retargeting when buying - as price will go up it
  will "follow up" with buy order price to keep `buy down interval` distance
  (as price it will go down it won't retarget as it would never buy anything)

  On buying NativeTrader puts 2 orders:
  - `sell order` at price of
     ((`buy price` * (1 + `buy order fee`)) * (1 + `profit interval`)) * (1 + `sell price fee`)
  - stop loss order at
      `buy price` * (1 - `stop loss interval`)
  """

  defmodule State do
    defstruct symbol: nil,
              strategy: nil,
              budget: nil,
              buy_order: nil,
              sell_order: nil,
              buy_down_interval: nil,
              profit_interval: nil,
              stop_loss_interval: nil,
              pair: nil
  end

  def start_link({symbol, strategy}) do
    GenServer.start_link(__MODULE__, {symbol, strategy}, name: :"#{__MODULE__}-#{symbol}")
  end

  def init({symbol, strategy}) do
    Logger.info("Trader starting", symbol: symbol, strategy: strategy)
    GenServer.cast(self(), {:init_strategy, strategy})
    :ok = UiWeb.Endpoint.subscribe("stream-#{symbol}")

    {:ok,
     %State{
       :symbol => symbol,
       :strategy => strategy
     }}
  end

  @doc """
  Blank strategy called when on init.
  """
  def handle_cast({:init_strategy, :blank}, state) do
    state = %State{prepare_state(state.symbol) | :strategy => :blank}
    {:noreply, state}
  end

  @doc """
  Most basic case - no trades ongoing so it will try to make limit buy order based
  on current price (from event) and substracting `buy_down_interval`
  """
  def handle_info(
        %{
          event: "trade_event",
          payload: %Hefty.Repo.Binance.TradeEvent{price: price, symbol: symbol}
        },
        %State{
          strategy: :blank,
          buy_order: nil,
          symbol: symbol,
          buy_down_interval: buy_down_interval,
          budget: budget
        } = state
      ) do
    current_price = D.new(price)
    buy_down_interval_d = D.new(buy_down_interval)

    D.set_context(%D.Context{D.get_context() | rounding: :floor, precision: 7})

    target_price = D.sub(current_price, D.mult(current_price, buy_down_interval_d))
    quantity = D.div(D.new(budget), target_price)

    # hack - to be deleted
    target_price = D.sub(target_price, D.mult(target_price, D.from_float(0.01)))

    Logger.info(
      "Placing order for #{symbol} @ #{D.to_float(target_price)},
      quantity: #{D.to_float(quantity)}"
    )

    # IO.inspect(Application.get_env(:binance, :secret_key))

    # start transaction here
    # insert new order

    {:ok, res} =
      @binance_client.order_limit_buy(
        symbol,
        D.to_float(quantity),
        D.to_float(target_price),
        "GTC"
      )

    # IO.inspect(D.to_float(target_price))
    # IO.inspect(quantity)
    IO.inspect(res, label: "Result from order placement - Binance")

    {:noreply, state}
  end

  defp prepare_state(symbol) do
    settings = fetch_settings(symbol)
    pair = fetch_pair(symbol)

    %State{
      symbol: settings.symbol,
      budget: settings.budget,
      buy_down_interval: settings.buy_down_interval,
      profit_interval: settings.profit_interval,
      stop_loss_interval: settings.stop_loss_interval,
      pair: pair
    }
  end

  defp fetch_settings(symbol) do
    from(nts in Hefty.Repo.NaiveTraderSetting,
      where: nts.platform == "Binance" and nts.symbol == ^symbol
    )
    |> Hefty.Repo.one()
  end

  defp fetch_pair(symbol) do
    query =
      from(p in Hefty.Repo.Binance.Pair,
        where: p.symbol == ^symbol
      )

    Hefty.Repo.one(query)
  end
end
