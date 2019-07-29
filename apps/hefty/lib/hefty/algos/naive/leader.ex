defmodule Hefty.Algos.Naive.Leader do
  use GenServer
  require Logger

  alias Hefty.Algos.Naive.Trader

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
    defstruct symbol: nil, budget: 0, chunks: 5, traders: []
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
    GenServer.cast(self(), :init_traders)
    {:ok, %State{symbol: symbol}}
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

  def handle_cast(:init_traders, state) do
    settings =
      from(nts in Hefty.Repo.NaiveTraderSetting,
        where: nts.platform == "Binance" and nts.symbol == ^state.symbol
      )
      |> Hefty.Repo.one()

    init_traders(settings, state)
  end

  def handle_cast(
        {:trade_finished, pid,
         %Hefty.Algos.Naive.Trader.State{
           :sell_order => %Hefty.Repo.Binance.Order{
             :trade_id => trade_id,
             :price => sell_order_price
           },
           :symbol => symbol
         }},
        state
      ) do
    Logger.info("Trade(#{trade_id}) finished at price of #{sell_order_price}")

    :ok =
      DynamicSupervisor.terminate_child(
        :"Hefty.Algos.Naive.DynamicSupervisor-#{symbol}",
        pid
      )

    new_traders = [
      start_new_trader(symbol, :blank, [])
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
        %State{symbol: symbol, traders: traders, chunks: chunks} = state
      ) do
    new_trader =
      case length(traders) < chunks do
        true ->
          Logger.info("Rebuy notification received, starting a new trader")
          start_new_trader(symbol, :blank, [])

        false ->
          Logger.info("Rebuy notification received but all chunks already used")
          traders
      end

    {:noreply, %{state | :traders => [new_trader | traders]}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, handle_dead_trader(pid, state)}
  end

  def handle_call(:fetch_traders, _from, state) do
    {:reply, state.traders, state}
  end

  # Safety fuse
  defp init_traders(%Hefty.Repo.NaiveTraderSetting{:trading => false}, state) do
    Logger.warn("Safety fuse triggered - trying to start non traded symbol")
    {:noreply, state}
  end

  defp init_traders(%Hefty.Repo.NaiveTraderSetting{:chunks => chunks, :budget => budget}, %State{
         :symbol => symbol
       }) do
    open_trades =
      symbol
      |> fetch_open_trades()

    traders =
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

    {:noreply,
     %State{
       symbol: symbol,
       budget: budget,
       chunks: chunks,
       traders: traders
     }}
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

  defp handle_dead_trader(pid, %State{:traders => traders, :symbol => symbol} = state) do
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
end
