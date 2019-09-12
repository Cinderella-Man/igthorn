defmodule Hefty.Algos.Naive.Leader do
  use GenServer
  require Logger

  alias Hefty.Algos.Naive.Trader
  alias Hefty.Repo.Binance.Order
  alias Hefty.Repo.NaiveTraderSetting

  alias Decimal, as: D

  import Ecto.Query, only: [from: 2]
  # import Ecto.Changeset, only: [cast: 3]

  @moduledoc """
    Naive server is reponsible for all naive traders.

    Main tasks:
    - reads total budget for naive strategy for symbol
    - start traders with budget chunk and strategy
    - monitor traders to start them again (when they completed their trade)
  """

  defmodule State do
    defstruct symbol: nil, settings: nil, traders: []
  end

  defmodule TraderState do
    defstruct pid: nil,
              ref: nil,
              state: nil
  end

  def start_link(symbol) do
    GenServer.start_link(__MODULE__, symbol, name: :"#{__MODULE__}-#{symbol}")
  end

  def init(symbol) do
    GenServer.cast(self(), {:init_traders, symbol})
    {:ok, nil}
  end

  def fetch_traders(symbol) do
    GenServer.call(:"#{__MODULE__}-#{symbol}", :fetch_traders)
  end

  def notify(symbol, :state, state) do
    GenServer.cast(:"#{__MODULE__}-#{symbol}", {:notify, :state_update, self(), state})
  end

  def notify(symbol, :rebuy) do
    GenServer.cast(:"#{__MODULE__}-#{symbol}", {:notify, :rebuy})
  end

  def update_settings(symbol, settings) do
    GenServer.cast(:"#{__MODULE__}-#{symbol}", {:update_settings, settings})
  end

  def is_price_level_available(symbol, target_price) do
    GenServer.call(:"#{__MODULE__}-#{symbol}", {:is_price_level_available, target_price})
  end

  @doc """
  Callback after startup. State is empty so it will be ignored
  """
  def handle_cast({:init_traders, symbol}, _state) do
    settings = fetch_settings(symbol)

    traders = init_traders(settings)

    {:noreply,
     %State{
       symbol: symbol,
       traders: traders,
       settings: settings
     }}
  end

  def handle_cast(
        {:trade_finished, pid,
         %Trader.State{
           :sell_order => %Order{
             :trade_id => trade_id,
             :price => sell_order_price
           },
           :trade => %Hefty.Repo.Trade{:profit_base_currency => profit},
           :symbol => symbol,
           :budget => previous_budget,
           :id => id
         } = old_trader_state},
        %State{:settings => settings} = state
      ) do
    Logger.info("Trader(#{id}) - Trade(#{trade_id}) finished at price of #{sell_order_price}")

    :ok =
      DynamicSupervisor.terminate_child(
        :"Hefty.Algos.Naive.DynamicSupervisor-#{symbol}",
        pid
      )

    new_budget = D.add(D.new(previous_budget), D.new(profit))

    settings = update_budget(settings, profit)

    Logger.info("Trader(#{id}) - Trade profit: #{profit} USDT")

    new_traders =
      case settings.status do
        "ON" ->
          [
            start_new_trader(symbol, :restart, %{
              old_trader_state
              | :buy_order => nil,
                :sell_order => nil,
                :stop_loss_triggered => false,
                :rebuy_notified => false,
                :budget => new_budget
            })
            | Enum.reject(state.traders, &(&1.pid == pid))
          ]

        _ ->
          Logger.info(
            "Ignoring the fact that trader died as we are in graceful shutdown mode for symbol #{
              symbol
            }"
          )

          Enum.reject(state.traders, &(&1.pid == pid))
      end

    {:noreply, %{state | :traders => new_traders, :settings => settings}}
  end

  @doc """
  Handles change of state notifications from traders. This should update local cache of traders
  """
  def handle_cast({:notify, :state_update, pid, %Trader.State{} = trader_state}, state) do
    index = Enum.find_index(state.traders, &(&1.pid == pid))

    case index do
      nil ->
        {:noreply, state}

      _ ->
        {old_trader_state, rest_of_traders} = List.pop_at(state.traders, index)

        new_trader_state = %{old_trader_state | :state => trader_state}

        {:noreply, %{state | :traders => [new_trader_state | rest_of_traders]}}
    end
  end

  @doc """
  Handles `rebuy` notifications from traders. This should spin new trader
  """
  def handle_cast(
        {:notify, :rebuy},
        %State{
          settings: %NaiveTraderSetting{
            symbol: symbol,
            chunks: chunks
          },
          traders: traders
        } = state
      ) do
    new_traders =
      case length(traders) < chunks do
        true ->
          Logger.info("Rebuy notification received, starting a new trader")
          [start_new_trader(symbol, :blank, []) | traders]

        false ->
          Logger.info("Rebuy notification received but all chunks already used")
          traders
      end

    {:noreply, %{state | :traders => new_traders}}
  end

  def handle_cast({:update_settings, settings}, %State{:traders => traders} = state) do
    Logger.info("Updating settings for all traders of symbol #{state.symbol}")

    traders
    |> Enum.map(&GenServer.cast(&1.pid, {:update_settings, settings}))

    new_traders =
      case settings.status do
        "SHUTDOWN" ->
          Logger.info("Shutting down all eligible traders of symbol #{state.symbol}")
          shutdown_eligible_traders(traders, state.symbol)

        _ ->
          Logger.debug("Status didn't change so ignoring")
          traders
      end

    {:noreply, %{state | :settings => settings, :traders => new_traders}}
  end

  @doc """
  Used for killing previously stopped traders that couldn't start because of price
  being taken by other trader
  """
  def handle_cast({:kill, pid}, %State{:symbol => symbol, :traders => traders} = state) do
    trader =
      traders
      |> Enum.find(&(&1.pid == pid))

    new_traders =
      case trader do
        %TraderState{:pid => pid, :ref => ref} ->
          kill_trader(pid, ref, symbol)
          traders |> Enum.reject(&(&1.pid == pid))

        _ ->
          Logger.warn("Something gone wrong. Unable to find trader to be killed")
          traders
      end

    {:noreply, %{state | :traders => new_traders}}
  end

  def handle_cast(
    {:reenable_rebuy, price},
    %State{
      :traders => traders,
      :settings => %{
        :rebuy_interval => interval
      },
    } = state) do

    trader = traders
      |> Enum.filter(&(&1.state.buy_order != nil))
      |> Enum.find(&within_range(&1.state, price, interval))

    new_traders = case trader do
      nil            -> Logger.info("Unable to find trader to reenable rebuy for. Nothing to do")
                        traders
      %TraderState{:state => %{:id => id}} -> Logger.info("Trader #{id} found to reenable rebuy flag")
                        GenServer.cast(trader.pid, :reenable_rebuy)
                        new_trader = %{trader | :state => %{trader.state | rebuy_notified: false}}
                        List.replace_at(traders, Enum.find_index(traders, &(within_range(&1.state, price, interval))), new_trader)
    end

    {
      :noreply,
      %{state | traders: new_traders}
    }
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, handle_dead_trader(pid, state)}
  end

  def handle_call(:fetch_traders, _from, state) do
    {:reply, state.traders, state}
  end

  def handle_call(
        {:is_price_level_available, target_price},
        _from,
        %State{
          :settings => %{
            :rebuy_interval => interval
          },
          :traders => traders
        } = state
      ) do
    {:reply, !Enum.find_value(traders, false, &within_range(&1.state, target_price, interval)), state}
  end

  defp within_range(%Trader.State{buy_order: nil}, _price, _interval), do: false

  defp within_range(%Trader.State{buy_order: %{:price => price}}, target_price, interval) do
    order_price = D.new(price)
    price = D.from_float(target_price)
    diff = D.sub(D.from_float(1.0), D.div(price, order_price))

    case D.cmp(diff, D.new(interval)) do
      :gt -> false
      _ -> true
    end
  end

  # Safety fuse
  defp init_traders(%NaiveTraderSetting{:status => "OFF"}) do
    Logger.warn("Safety fuse triggered - trying to start non traded symbol")
    []
  end

  defp init_traders(%NaiveTraderSetting{
         :symbol => symbol
       }) do
    open_trades = fetch_open_trades(symbol)

    case open_trades do
      [] ->
        Logger.info("No open trades so starting :blank trader", symbol: symbol)
        [start_new_trader(symbol, :blank, [])]

      x ->
        Logger.info("There's some exisitng trades ongoing - starting trader for each",
          symbol: symbol
        )

        Enum.map(x, &start_new_trader(symbol, :continue, &1))
    end
  end

  defp fetch_settings(symbol) do
    from(nts in Hefty.Repo.NaiveTraderSetting,
      where: nts.platform == "Binance" and nts.symbol == ^symbol
    )
    |> Hefty.Repo.one()
  end

  defp fetch_open_trades(symbol) do
    symbol
    |> fetch_open_orders()
    |> Enum.group_by(& &1.trade_id)
    |> Map.values()
    |> Enum.filter(&is_open_trade(&1))
  end

  defp fetch_open_orders(symbol) do
    from(o in Hefty.Repo.Binance.Order,
      where: o.symbol == ^symbol,
      where: o.status != "CANCELED",
      order_by: o.time
    )
    |> Hefty.Repo.all()
  end

  # Starting traders based on orders from db.
  # There is possibility of getting multiple canceled orders
  # which needs to be filtered out
  defp start_new_trader(symbol, strategy, orders) when is_list(orders) do
    buy_order =
      Enum.find(
        orders,
        &(&1.side == "BUY" &&
            (&1.status == "NEW" || &1.status == "FILLED" || &1.status == "PARTIALLY_FILLED"))
      )

    sell_order =
      Enum.find(
        orders,
        &(&1.side == "SELL" && (&1.status == "NEW" || &1.status == "PARTIALLY_FILLED"))
      )

    trade =
      case buy_order do
        %Order{:trade_id => trade_id} -> Hefty.Trades.fetch(trade_id)
        _ -> nil
      end

    start_new_trader(symbol, strategy, %Trader.State{
      :buy_order => buy_order,
      :sell_order => sell_order,
      :trade => trade
    })
  end

  defp start_new_trader(symbol, strategy, %Trader.State{} = state) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        :"Hefty.Algos.Naive.DynamicSupervisor-#{symbol}",
        {Hefty.Algos.Naive.Trader, {symbol, strategy, state}}
      )

    ref = Process.monitor(pid)

    %TraderState{:pid => pid, :ref => ref, :state => state}
  end

  defp is_open_trade(orders) do
    orders
    |> Enum.count(&(&1.status == "FILLED"))
    |> (fn c -> c < 2 end).()
  end

  def kill_trader(pid, ref, symbol) do
    Process.demonitor(ref)

    :ok =
      DynamicSupervisor.terminate_child(
        :"Hefty.Algos.Naive.DynamicSupervisor-#{symbol}",
        pid
      )
  end

  defp update_budget(settings, profit) do
    query =
      "UPDATE naive_trader_settings " <>
        "SET budget = cast(budget as double precision) + #{profit} " <>
        "WHERE symbol='#{settings.symbol}';"

    # probably check this?
    Ecto.Adapters.SQL.query!(Hefty.Repo, query, [])

    fetch_settings(settings.symbol)
  end

  defp handle_dead_trader(
         pid,
         %State{
           :traders => traders,
           :settings => %NaiveTraderSetting{
             :symbol => symbol
           }
         } = state
       ) do
    Logger.info("Leader restarts process as it died")

    index = Enum.find_index(traders, &(&1.pid == pid))

    if is_number(index) do
      Logger.info("Trader found in the list of traders. Removing")
      {%{:state => state_dump}, rest_of_traders} = List.pop_at(traders, index)

      new_trader = start_new_trader(symbol, :restart, state_dump)

      %{state | :traders => [new_trader | rest_of_traders]}
    else
      Logger.info("Unable to find trader in list of traders. Skipping removal")
      state
    end
  end

  defp shutdown_eligible_traders(traders, symbol) do
    traders
    |> Enum.filter(&is_shutdown_eligible(&1.state))
    |> Enum.map(&GenServer.call(&1.pid, :stop_trading))
    |> Enum.map(&kill_trader(&1.pid, &1.ref, symbol))

    traders
    |> Enum.reject(&is_shutdown_eligible(&1.state))
  end

  defp is_shutdown_eligible(%Trader.State{:buy_order => nil}), do: true

  defp is_shutdown_eligible(%Trader.State{
         :buy_order => %{
           :executed_quantity => "0.00000000"
         }
       }),
       do: true

  defp is_shutdown_eligible(_), do: false
end
