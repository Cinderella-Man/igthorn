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

  On buying NaiveTrader puts 2 orders:
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
              rebuy_interval: nil,
              rebuy_notified: false,
              retarget_interval: nil,
              pair: nil
  end

  def start_link({symbol, strategy, data}) do
    GenServer.start_link(__MODULE__, {symbol, strategy, data})
  end

  def init({symbol, strategy, data}) do
    Logger.info("Trader starting(symbol: #{symbol}, strategy: #{strategy})")
    GenServer.cast(self(), {:init_strategy, strategy, data})

    Logger.debug("Trader subscribing to #{"stream-#{symbol}"}")
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
  def handle_cast({:init_strategy, :blank, []}, state) do
    state = %State{prepare_state(state.symbol) | :strategy => :blank}
    Logger.debug("Trader initialized successfully")
    {:noreply, state}
  end

  @doc """
  Continue strategy called when on init.
  """
  def handle_cast({:init_strategy, :continue, orders}, state) do
    state = %State{prepare_state(state.symbol) | :strategy => :blank}
    buy_order = Enum.find(orders, &(&1.side == "BUY"))
    sell_order = Enum.find(orders, &(&1.side == "SELL"))

    Logger.debug("Trader initialized successfully")
    {:noreply, %{state | :buy_order => buy_order, :sell_order => sell_order}}
  end

  @doc """
  Blank strategy called when on init.
  """
  def handle_cast({:init_strategy, :rebuy, %{:sell_price => sell_price}}, state) do
    base_state = prepare_state(state.symbol)
    buy_order = place_buy_order(sell_price, base_state)
    state = %State{base_state | :strategy => :blank, :buy_order => buy_order}
    Logger.debug("Trader initialized successfully")
    {:noreply, state}
  end

  @doc """
  Situation:

  Clean slate - no buy trade placed

  It will try to make limit buy order based on current price (from event) taking under
  consideration substracting `buy_down_interval`
  """
  def handle_info(
        %{
          event: "trade_event",
          payload: %Hefty.Repo.Binance.TradeEvent{price: price}
        },
        %State{
          buy_order: nil
        } = state
      ) do
    order = place_buy_order(price, state)
    {:noreply, %State{state | :buy_order => order}}
  end

  @doc """
  Situation:

  Buy order was placed but it didn't get filled yet. Incoming event
  points to that buy order

  Updates buy order as incoming transaction is filling our buy order
  If buy order is now fully filled it will submit sell order.
  """
  def handle_info(
        %{
          event: "trade_event",
          payload:
            %Hefty.Repo.Binance.TradeEvent{
              buyer_order_id: order_id
            } = event
        },
        %State{
          buy_order:
            %Hefty.Repo.Binance.Order{
              order_id: order_id,
              symbol: symbol,
              time: time
            } = buy_order,
          profit_interval: profit_interval,
          pair: %Hefty.Repo.Binance.Pair{price_tick_size: tick_size}
        } = state
      ) do
    Logger.info("Transaction of #{event.quantity} for BUY order #{order_id} received")
    {:ok, current_buy_order} = @binance_client.get_order(symbol, time, order_id)

    {:ok, new_state} =
      case current_buy_order.executed_qty == current_buy_order.orig_qty do
        true ->
          Logger.info("Current buy order has been filled. Submitting sell order")

          Hefty.Repo.transaction(fn ->
            sell_order = create_sell_order(buy_order, profit_interval, tick_size)

            new_buy_order =
              update_order(buy_order, %{
                :executed_quantity => current_buy_order.executed_qty,
                :status => current_buy_order.status
              })

            %{state | :buy_order => new_buy_order, :sell_order => sell_order}
          end)

        false ->
          new_buy_order =
            update_order(buy_order, %{
              :executed_quantity => current_buy_order.executed_qty,
              :status => current_buy_order.status
            })

          {:ok, %{state | :buy_order => new_buy_order}}
      end

    {:noreply, new_state}
  end

  @doc """
  Situation:

  Buy order and sell order are already placed. Incoming event points to
  our sell order.

  Updates sell order as incoming transaction is filling our sell order
  If sell order is now fully filled it should stop trading.
  """
  def handle_info(
        %{
          event: "trade_event",
          payload:
            %Hefty.Repo.Binance.TradeEvent{
              seller_order_id: order_id
            } = event
        },
        %State{
          sell_order:
            %Hefty.Repo.Binance.Order{
              order_id: order_id,
              symbol: symbol,
              time: time
            } = sell_order
        } = state
      ) do
    Logger.info("Transaction of #{event.quantity} for SELL order #{order_id} received")

    {:ok, current_sell_order} = @binance_client.get_order(symbol, time, order_id)

    new_sell_order =
      update_order(sell_order, %{
        :executed_quantity => current_sell_order.executed_qty,
        :status => current_sell_order.status
      })

    new_state = %{state | :sell_order => new_sell_order}

    case current_sell_order.executed_qty == current_sell_order.orig_qty do
      true ->
        Logger.info("Current sell order has been filled. Process can terminate")

        GenServer.cast(
          :"#{Hefty.Algos.Naive.Leader}-#{symbol}",
          {:trade_finished, self(), new_state}
        )

        {:noreply, new_state}

      false ->
        {:noreply, new_state}
    end
  end

  @doc """
  Situation:

  Buy order is placed and not filled, price is increasing so we need check did
  it grow more than `retarget_interval`, then we need to cancel order and
  place another one based on current value
  """
  def handle_info(
        %{
          event: "trade_event",
          payload: %Hefty.Repo.Binance.TradeEvent{price: price}
        },
        %State{
          buy_order:
            %Hefty.Repo.Binance.Order{
              price: order_price,
              executed_quantity: "0.00000"
            } = buy_order,
          retarget_interval: retarget_interval
        } = state
      ) do
    d_price = D.new(price)
    d_order_price = D.new(order_price)

    retarget_price = D.add(d_order_price, D.mult(d_order_price, D.new(retarget_interval)))

    case D.comp(retarget_price, d_price) do
      # retarget_price < current_price
      1 ->
        # cancel order in Binance
        # update order in DB
        {:noreply, %{state | :buy_order => nil}}

      _ ->
        {:noreply, state}
    end
  end

  @doc """
  Situation:

  Buy and sell orders were placed, only buy got filled.
  Price is dropping - stop loss should be triggered
  """
  def handle_info(
        %{
          event: "trade_event",
          payload: %Hefty.Repo.Binance.TradeEvent{price: current_price}
        },
        %State{
          buy_order:
            %Hefty.Repo.Binance.Order{
              price: buy_price,
              executed_quantity: matching_quantity,
              original_quantity: matching_quantity
            } = buy_order,
          sell_order: sell_order,
          stop_loss_interval: stop_loss_interval
        } = state
      ) do
    d_current_price = D.new(current_price)
    d_buy_price = D.new(buy_price)

    stop_loss_price = D.sub(d_buy_price, D.mult(d_buy_price, D.new(stop_loss_interval)))

    case D.comp(stop_loss_price, d_current_price) do
      # retarget_price >= current_price
      -1 ->
        # cancel SELL order in Binance
        # update order in DB
        # place new sell order
        # "kill" process
        {:noreply, %{state | :sell_order => new_sell_order}}

      _ ->
        {:noreply, state}
    end
  end

  # TO IMPLEMENT
  # Price went below buy order but no sell order neither quantity got updated - update record and possibly add sell order
  # Price went above sell order but quantity wasn't updated - update record and die

  @doc """
  Catch all - should never happen in production - here for developing
  """
  def handle_info(
        %{
          event: "trade_event",
          payload: %Hefty.Repo.Binance.TradeEvent{}
        },
        %State{} = state
      ) do
    # Logger.debug("Another trade event received - TBFixed")
    {:noreply, state}
  end

  defp place_buy_order(price, %State{
         buy_order: nil,
         symbol: symbol,
         buy_down_interval: buy_down_interval,
         budget: budget,
         pair: %Hefty.Repo.Binance.Pair{
           price_tick_size: tick_size,
           quantity_step_size: quantity_step_size
         }
       }) do
    target_price = calculate_target_price(price, buy_down_interval, tick_size)
    quantity = calculate_quantity(budget, target_price, quantity_step_size)

    Logger.info("Placing BUY order for #{symbol} @ #{target_price}, quantity: #{quantity}")

    {:ok, res} =
      @binance_client.order_limit_buy(
        symbol,
        quantity,
        target_price,
        "GTC"
      )

    Logger.info("Successfully placed an BUY order #{res.order_id}")

    store_order(res)
  end

  defp prepare_state(symbol) do
    settings = fetch_settings(symbol)
    pair = fetch_pair(symbol)

    Logger.debug("Starting trader on symbol #{settings.symbol} with budget of #{inspect D,div(D.new(settings.budget), D.new(settings.chunks))}")

    %State{
      symbol: settings.symbol,
      budget: D.div(D.new(settings.budget), D.new(settings.chunks)),
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

  defp store_order(%Binance.OrderResponse{} = response, trade_id \\ nil) do
    Logger.info("Storing order #{response.order_id} to db")

    %Hefty.Repo.Binance.Order{
      :order_id => response.order_id,
      :symbol => response.symbol,
      :client_order_id => response.client_order_id,
      :price => response.price,
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
      :trade_id => trade_id || response.order_id
    }
    |> Hefty.Repo.insert()
    |> elem(1)
  end

  defp create_sell_order(
         %Hefty.Repo.Binance.Order{
           symbol: symbol,
           price: buy_price,
           original_quantity: quantity,
           trade_id: trade_id
         },
         profit_interval,
         tick_size
       ) do
    # close enough
    sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)
    quantity = D.to_float(D.new(quantity))

    Logger.info("Placing SELL order for #{symbol} @ #{sell_price}, quantity: #{quantity}")

    {:ok, res} =
      @binance_client.order_limit_sell(
        symbol,
        quantity,
        sell_price,
        "GTC"
      )

    Logger.info("Successfully placed an SELL order #{res.order_id}")

    store_order(res, trade_id)
  end

  defp calculate_sell_price(buy_price, profit_interval, tick_size) do
    fee = 1.001
    buy_price = D.new(buy_price)
    real_buy_price = D.mult(buy_price, D.from_float(fee))
    tick = D.new(tick_size)

    net_target_price = D.mult(real_buy_price, D.add(1, D.new(profit_interval)))
    gross_target_price = D.mult(net_target_price, D.from_float(fee))
    D.to_float(D.mult(D.div_int(gross_target_price, tick), tick))
  end

  defp update_order(%Hefty.Repo.Binance.Order{} = order, %{} = changes) do
    changeset = Ecto.Changeset.change(order, changes)

    case Hefty.Repo.update(changeset) do
      {:ok, struct} -> struct
      {:error, _changeset} -> throw("Unable to update buy order")
    end
  end
end
