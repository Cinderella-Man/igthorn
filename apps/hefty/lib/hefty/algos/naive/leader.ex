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
    defstruct settings: nil, traders: []
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

  @doc """
  Callback after startup. State is empty so it will be ignored
  """
  def handle_cast({:init_traders, symbol}, _state) do
    settings =
      from(nts in Hefty.Repo.NaiveTraderSetting,
        where: nts.platform == "Binance" and nts.symbol == ^symbol
      )
      |> Hefty.Repo.one()

    traders = init_traders(settings)

    {:noreply,
     %State{
       traders: traders,
       settings: settings
     }}
  end

  def handle_cast(
        {:trade_finished, pid,
         %Trader.State{
           :buy_order => %Order{} = buy_order,
           :sell_order =>
             %Order{
               :trade_id => trade_id,
               :price => sell_order_price
             } = sell_order,
           :symbol => symbol,
           :budget => previous_budget,
           :id => id
         } = old_trader_state},
        state
      ) do
    Logger.info("Trader(#{id}) - Trade(#{trade_id}) finished at price of #{sell_order_price}")

    :ok =
      DynamicSupervisor.terminate_child(
        :"Hefty.Algos.Naive.DynamicSupervisor-#{symbol}",
        pid
      )

    outcome = calculate_outcome(buy_order, sell_order)
    new_budget = D.add(D.new(previous_budget), outcome)

    Logger.info("Trader(#{id}) - Trade outcome: #{D.to_float(outcome)} USDT")

    new_traders = [
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

    {:noreply, %{state | :traders => new_traders}}
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

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, handle_dead_trader(pid, state)}
  end

  def handle_call(:fetch_traders, _from, state) do
    {:reply, state.traders, state}
  end

  # Safety fuse
  defp init_traders(%NaiveTraderSetting{:trading => false}) do
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
      where: o.status != "CANCELLED",
      order_by: o.time
    )
    |> Hefty.Repo.all()
  end

  # Starting traders based on orders from db.
  # There is possibility of getting multiple cancelled orders
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

    start_new_trader(symbol, strategy, %Trader.State{
      :buy_order => buy_order,
      :sell_order => sell_order
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

  defp calculate_outcome(
         %Order{:price => buy_price, :original_quantity => quantity},
         %Order{:price => sell_price}
       ) do
    fee = D.new(Application.get_env(:hefty, :trading).defaults.fee)
    spent_without_fee = D.mult(D.new(buy_price), D.new(quantity))
    total_spent = D.add(spent_without_fee, D.mult(spent_without_fee, fee))

    gain_without_fee = D.mult(D.new(sell_price), D.new(quantity))
    total_gain = D.sub(gain_without_fee, D.mult(gain_without_fee, fee))

    D.sub(total_gain, total_spent)
  end
end
