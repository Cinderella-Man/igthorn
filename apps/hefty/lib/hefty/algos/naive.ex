defmodule Hefty.Algo.Naive do
  def flip_trading(symbol) do
    Hefty.Algos.Naive.Server.flip_trading(symbol)
  end

  def turn_on(symbol) do
    Hefty.Algos.Naive.Server.turn_on(symbol)
  end

  def turn_off(symbol) do
    Hefty.Algos.Naive.Server.turn_off(symbol)
  end
end
