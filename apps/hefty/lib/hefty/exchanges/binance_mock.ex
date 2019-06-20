defmodule Hefty.Exchanges.BinanceMock do
  use GenServer

  @doc """
  Holds a copy of all placed orders
  """
  defmodule State do
    defstruct orders: []
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, %State{}}
  end

  def get_account() do
    Binance.get_account()
  end

  def get_exchange_info() do
    Binance.get_exchange_info()
  end

  def order_limit_buy(symbol, quantity, price, "GTC") do
    fake_order = %{generate_fake_order(symbol, quantity, price) | :side => "BUY"}

    GenServer.cast(
      Hefty.Streaming.Backtester.SimpleStreamer,
      {:order, fake_order}
    )

    GenServer.cast(
      __MODULE__,
      {:add_order, fake_order}
    )

    fake_order
  end

  def order_limit_sell(symbol, quantity, price, "GTC") do
    fake_order = %{generate_fake_order(symbol, quantity, price) | :side => "SELL"}

    GenServer.cast(
      Hefty.Streaming.Backtester.SimpleStreamer,
      {:order, fake_order}
    )

    GenServer.cast(
      __MODULE__,
      {:add_order, fake_order}
    )

    fake_order
  end

  def get_order(symbol, time, order_id) do
    GenServer.call(__MODULE__, {:get_order, symbol, time, order_id})
  end

  defp generate_fake_order(symbol, quantity, price) do
    current_timestamp = :os.system_time(:millisecond)
    order_id = :rand.uniform(1_000_000)

    Binance.OrderResponse.new(%{
      client_order_id: :crypto.hash(:md5, order_id) |> Base.encode16(),
      executed_qty: "0.00000",
      order_id: order_id,
      orig_qty: quantity,
      price: Float.to_string(price),
      status: "NEW",
      symbol: symbol,
      time_in_force: "GTC",
      transact_time: current_timestamp,
      type: "LIMIT"
    })
  end

  def handle_call({:add_order, order}, %State{:orders => orders} = state) do
    {:noreply, order, %{state | :orders => [order | orders]}}
  end

  def handle_call({:get_order, symbol, time, order_id}, _from, %State{:orders => orders} = state) do
    result =
      orders
      |> Enum.find(nil, &(&1.symbol == symbol and &1.time == time and &1.order_id == order_id))

    {:reply, result, state}
  end
end
