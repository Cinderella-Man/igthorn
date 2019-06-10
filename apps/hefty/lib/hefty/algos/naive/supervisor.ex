defmodule Hefty.Algos.Naive.Supervisor do
  use Supervisor

  @doc """
  Top level supervisor - there's only one process of this kind running
  across all symbols that contains Server (registry of symbol ralated
  process underneath the DynamicSupervisor)
  """

  def start_link([]) do
    Supervisor.start_link(
      __MODULE__,
      [],
      name: __MODULE__
    )
  end

  def init(_args) do
    Supervisor.init(
      [
        {
          DynamicSupervisor,
          strategy: :one_for_one, name: Hefty.Algos.Naive.DynamicSupervisor
        },
        {Hefty.Algos.Naive.Server, []}
      ],
      strategy: :one_for_all
    )
  end
end
