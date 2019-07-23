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
              buy_placed: false,
              sell_placed: false,
              buy_price: nil,
              sell_price: nil,
              rebuy_triggered: false
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
    GenServer.cast(:"#{__MODULE__}-#{symbol}", {:notify, :state_update, state})
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
           :sell_order => %Hefty.Repo.Binance.Order{:price => sell_order_price},
           :symbol => symbol
         }},
        state
      ) do
    Logger.info("Trade finished at price of #{sell_order_price}")

    :ok =
      DynamicSupervisor.terminate_child(
        :"Hefty.Algos.Naive.DynamicSupervisor-#{symbol}",
        pid
      )

    new_traders = [
      start_new_trader(symbol, :rebuy, %{:sell_price => sell_order_price})
      | Enum.reject(state.traders, &(&1.pid == pid))
    ]

    {:noreply, %{state | :traders => new_traders}}
  end

  @doc """
  Handles change of state notifications from traders. This should update local cache of traders
  """
  def handle_cast({:notify, :state_update, pid, %Trader.State{} = _trader_state}, state) do
    index = Enum.find_index(state.traders, &(&1.pid == pid))

    case index do
      nil ->
        {:noreply, state}

      _ ->
        {:noreply, state}
        # {old_trader_state, rest_of_traders} = List.pop_at()

        # new_traders = List.replace_at(
        #         state.traders,
        #         index,
        #         %TraderState{
        #           pid: nil,
        #           ref: nil,
        #           buy_placed: false,
        #           sell_placed: false,
        #           buy_price: nil,
        #           sell_price: nil,
        #           rebuy_triggered: false                
        #         }
        #        )
    end
  end

  @doc """
  Handles `rebuy` notifications from traders. This should spin new trader
  """
  def handle_cast({:notify, :rebuy}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :shutdown}, state) do
    Logger.info("Leader ignoring the fact that process died as it died normally")
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :killed}, state) do
    Logger.info("Leader ignoring the fact that process died as it was killed")
    {:noreply, state}
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
  end

  defp fetch_open_orders(symbol) do
    from(o in Hefty.Repo.Binance.Order,
      where: o.symbol == ^symbol
    )
    |> Hefty.Repo.all()
  end

  defp start_new_trader(symbol, strategy, data) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        :"Hefty.Algos.Naive.DynamicSupervisor-#{symbol}",
        {Hefty.Algos.Naive.Trader, {symbol, strategy, data}}
      )

    ref = Process.monitor(pid)

    %TraderState{:pid => pid, :ref => ref}
  end
end
