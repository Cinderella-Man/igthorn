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
          budget: budget,
          pair: %Hefty.Repo.Binance.Pair{price_tick_size: tick_size, quantity_step_size: quantity_step_size}
        } = state
      ) do

    target_price = calculate_target_price(price, buy_down_interval, tick_size)
    quantity = calculate_quantity(budget, target_price, quantity_step_size)

    Logger.info("Placing order for #{symbol} @ #{target_price}, quantity: #{quantity}")

    {:ok, res} =
      @binance_client.order_limit_buy(
        symbol,
        quantity,
        target_price,
        "GTC"
      )

    Logger.info("Successfully placed an order #{res.order_id}")

    order = store_order(res)

    {:noreply, %State{state | :buy_order => order}}
  end

  @doc """
  Blank strategy will try to catch up to growing price so this is the code responsible for that.
  It checks that buy order is already placed, checks has price moved up enough to cancel current order
  and put another order at higher price
  """
  def handle_info(
        %{
          event: "trade_event",
          payload: %Hefty.Repo.Binance.TradeEvent{}
        },
        %State{} = state
      ) do

  Logger.debug("Another trade event received - TBFixed")
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

  defp calculate_target_price(price, buy_down_interval, tick_size) do
    current_price = D.new(price)
    interval = D.new(buy_down_interval)
    tick = D.new(tick_size)

    # not necessarily legal price
    exact_target_price = D.sub(current_price, D.mult(current_price, interval))

    D.to_float(D.mult(D.div_int(exact_target_price, tick), tick))
  end

  defp calculate_quantity(budget, price, quantity_step_size) do
    budget = D.new(budget)
    step = D.new(quantity_step_size)
    price = D.from_float(price)

    # not necessarily legal quantity
    exact_target_quantity = D.div(budget, price)

    D.to_float(D.mult(D.div_int(exact_target_quantity, step), step))
  end

  defp store_order(%Binance.OrderResponse{} = response) do
    Logger.info("Storing order #{response.order_id} to db")
    %Hefty.Repo.Binance.Order{
      :order_id => response.order_id,
      :symbol => response.symbol,
      :client_order_id => response.client_order_id,
      :price => response.client_order_id,
      :original_quantity => response.orig_qty,
      :executed_quantity => response.executed_qty,
      # :cummulative_quote_quantity => response.X, # missing??
      :status => response.status,
      :time_in_force => response.time_in_force,
      :type => response.type,
      :side => response.side,
      # :stop_price => response.X, # missing ??
      # :iceberg_quantity => response.X, # missing ??
      :time => response.transact_time,
      # :update_time => response.X, # missing ??
      # :is_working => response.X, # gave up on this
      :strategy => "#{__MODULE__}",
      # :matching_order => null, # ignored here as it's a buy order
    }
    |> Hefty.Repo.insert() |> elem(1)
  end
end
