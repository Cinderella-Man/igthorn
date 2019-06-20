defmodule Hefty.Application do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        {Hefty.Repo, []},
        {Hefty.Streaming.Binance.Supervisor, []},
        # used for backtesting
        {Hefty.Streaming.Backtester.SimpleStreamer, []},
        {Hefty.Algos.Naive.Supervisor, []}
      ],
      strategy: :one_for_one,
      name: Hefty.Supervisor
    )
  end
end
