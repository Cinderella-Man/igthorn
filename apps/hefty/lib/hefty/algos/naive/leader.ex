defmodule Hefty.Algos.Naive.Leader do
  use GenServer
  require Logger

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

  def start_link(symbol) do
    GenServer.start_link(__MODULE__, symbol, name: :"#{__MODULE__}-#{symbol}")
  end

  def init(symbol) do
    GenServer.cast(self(), :init_traders)
    {:ok, %State{symbol: symbol}}
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
        {:trade_finished,
         %Hefty.Algos.Naive.Trader.State{
           :sell_order => %Hefty.Repo.Binance.Order{:price => sell_order_price}
         }},
        state
      ) do
    Logger.info("Trade finished at price of #{sell_order_price}")
    # todo: start new non-blank trader here
  end

  def handle_info({:DOWN, ref, :process, pid, :normal}, state) do
    new_traders =
      case Enum.find(state.traders, nil, fn t -> t == {pid, ref} end) do
        nil ->
          Logger.warn("Something gone wrong - received :normal :DOWN from unknown process")
          state.traders
        _ ->
          Enum.reject(state.traders, fn t -> t == {pid, ref} end)
      end

    {:noreply, %{state | :traders => new_traders}}
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
          [start_new_trader(symbol)]

        x ->
          Logger.info("There's some exisitng trades ongoing - starting trader for each",
            symbol: symbol
          )

          Enum.map(x, &start_trader(&1))
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
    |> Enum.group_by(&(&1.matching_order || &1.id))
    |> Map.keys()
  end

  defp fetch_open_orders(symbol) do
    from(o in Hefty.Repo.Binance.Order,
      where: o.symbol == ^symbol,
      where: (o.type == "BUY" and is_nil(o.matching_order)) or o.type == "SELL"
    )
    |> Hefty.Repo.all()
  end

  defp start_new_trader(symbol) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        :"Hefty.Algos.Naive.DynamicSupervisor-#{symbol}",
        {Hefty.Algos.Naive.Trader, {symbol, :blank}}
      )

    ref = Process.monitor(pid)

    {pid, ref}
  end

  defp start_trader(orders) do
    IO.inspect("Starting trader for orders:")
    Enum.map(orders, &IO.puts(&1.id))
  end
end
