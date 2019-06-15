defmodule Hefty.Algos.Naive.Leader do
  use GenServer

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

  # Safety fuse
  defp init_traders(%Hefty.Repo.NaiveTraderSetting{:trading => false}, state),
    do: {:noreply, state}

  defp init_traders(%Hefty.Repo.NaiveTraderSetting{:chunks => chunks, :budget => budget}, %State{:symbol => symbol}) do
    open_trades =
      symbol
      |> fetch_open_trades()

    case open_trades do
      [] -> start_new_trader(symbol)
      x -> Enum.map(x, &start_trader(&1))
    end

    {:noreply,
     %State{
       symbol: symbol,
       budget: budget,
       chunks: chunks
     }}
  end

  defp fetch_open_trades(symbol) do
    symbol
    |> fetch_open_orders()
    |> Enum.group_by(&(&1.matching_order || &1.id))
    |> Map.keys()
  end

  defp fetch_open_orders(symbol) do
    from(o in Hefty.Repo.Order,
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
