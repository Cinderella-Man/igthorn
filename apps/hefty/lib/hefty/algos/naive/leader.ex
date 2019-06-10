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
    defstruct symbol: nil, free_budget: 0, locked_budget: 0, traders: []
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
  defp init_traders(%Hefty.Repo.NaiveTraderSetting{:trading => false}, state), do: {:noreply, state}
  defp init_traders(_settings, state) do
    open_trades = fetch_open_trades(state.symbol)

    IO.inspect(open_trades)

    {:noreply, state}
  end

  defp fetch_open_trades(symbol) do
    from(o in Hefty.Repo.Binance.Order,
      where: o.symbol == ^symbol
    )
    |> Hefty.Repo.all()
  end
end
