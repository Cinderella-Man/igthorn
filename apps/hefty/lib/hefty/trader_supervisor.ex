defmodule Hefty.TraderSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(
      __MODULE__,
      [],
      name: __MODULE__
    )
  end

  def init(_args) do
    children = [
      worker(Hefty.NaiveTrader, [])
    ]

    opts = [strategy: :simple_one_for_one, max_restarts: 5, max_seconds: 5]

    Supervisor.init(
      children,
      opts
    )
  end
end
