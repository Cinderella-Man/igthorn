defmodule Hefty.Algos.Naive.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(
      __MODULE__,
      [],
      name: __MODULE__
    )
  end

  def init() do
    Supervisor.init(
      [
        {
          DynamicSupervisor,
          strategy: :one_for_one, name: :"#{Hefty.Algos.Naive.DynamicSupervisor}"
        },
        {Hefty.Algos.Naive.Server, []}
      ],
      strategy: :one_for_all
    )
  end
end
