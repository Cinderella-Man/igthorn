defmodule Hefty.Algos.Naive.Supervisor do
  use Supervisor

  def start_link(symbol) do
    Supervisor.start_link(
      __MODULE__,
      [symbol],
      name: :"#{__MODULE__}-#{symbol}"
    )
  end

  def init(symbol) do
    Supervisor.init(
      [
        {
          DynamicSupervisor,
          strategy: :one_for_one, name: :"#{Hefty.Algos.Naive.DynamicTraderSupervisor}-#{symbol}"
        },
        {Hefty.Algos.Naive.Server, [symbol]}
      ],
      strategy: :one_for_all
    )
  end
end
