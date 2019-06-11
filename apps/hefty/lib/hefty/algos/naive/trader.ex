defmodule Hefty.Algos.Naive.Trader do
  use GenServer

  @moduledoc """
  Hefty.Algos.Naive.Trader module is responsible for making a trade(buy + sell)
  on a single symbol.

  Naive trader is simple strategy which hopes that it will get on more raising
  waves than drops.

  Idea is based on "My Adventures in Automated Crypto Trading" presentation
  by Timothy Clayton @ https://youtu.be/b-8ciz6w9Xo?t=2297

  It requires few informations to work:
  - symbol
  - budget (amount of coins in "quote" currency)
  - profit interval (expected net profit in % - this will be used to set
  `sell orders` at level of `buy price`+`buy_fee`+`sell_fee`+`expected profit`)
  - buy down interval (expected buy price in % under current value)
  - chunks (split of budget to transactions - for example 5 represents
  up 5 transactions at the time - none of them will be more than 20%
  of budget*)
  - stop loss interval (defines % of value that stop loss order will be at)

  NaiveTrader implements retargeting when buying - as price will go up it
  will "follow up" with buy order price to keep `buy down interval` distance
  (as price it will go down it won't retarget as it would never buy anything)

  On buying NativeTrader puts 2 orders:
  - `sell order` at price of
     ((`buy price` * (1 + `buy order fee`)) * (1 + `profit interval`)) * (1 + `sell price fee`)
  - stop loss order at
      `buy price` * (1 - `stop loss interval`)
  """

  defmodule State do
    defstruct symbol: nil, strategy: nil, budget: 0
  end

  def start_link({symbol, strategy}) do
    GenServer.start_link(__MODULE__, {symbol, strategy}, name: :"#{__MODULE__}-#{symbol}")
  end

  def init({symbol, strategy}) do
    GenServer.cast(self(), {:init_strategy, strategy})
    :ok = UiWeb.Endpoint.subscribe("stream-#{symbol}")

    {:ok,
     %State{
       :symbol => symbol,
       :strategy => strategy
     }}
  end

  def handle_cast({:init_strategy, :blank}, state) do
    IO.inspect("Init_strategy called")
    {:noreply, state}
  end

  def handle_info(%{event: "trade_event", payload: event}, state) do
    IO.inspect(event, label: "Trade event received by trader")
    {:noreply, state}
  end
end
