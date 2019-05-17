defmodule Hefty.Streaming.Supervisor do
  use Supervisor

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
          strategy: :one_for_one, restart: :temporary, name: Hefty.Streaming.DynamicStreamerSupervisor
        },
        {Hefty.Streaming.Server, []}
      ],
      strategy: :one_for_all
    )
  end
end
