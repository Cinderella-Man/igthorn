defmodule Hefty.Application do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        {Hefty.Repo, []},
        {Hefty.Streaming.Binance.Supervisor, []},
        {
          DynamicSupervisor,
          strategy: :one_for_one, name: Hefty.Algos.Naive.Supervisor
        }
      ],
      strategy: :one_for_one,
      name: Hefty.Supervisor
    )
  end
end
