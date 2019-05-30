defmodule Hefty.Algos.Naive.Server do
  use GenServer

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
    GenServer.start_link(__MODULE__, [symbol], name: :"#{__MODULE__}-#{symbol}")
  end

  def init(symbol) do
    {:ok, %State{symbol: symbol}}
  end
end
