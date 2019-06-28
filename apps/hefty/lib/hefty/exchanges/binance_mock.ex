defmodule Hefty.Exchanges.BinanceMock do
  use GenServer

  require Logger

  @doc """
  Holds a copy of all placed orders
  """
  defmodule State do
    defstruct orders: [], subscriptions: []
  end

  def start_link([]) do
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

  @spec order_limit_buy(String.t(), float(), float(), String.t()) ::
          {:ok, %Binance.OrderResponse{}}
  def order_limit_buy(symbol, quantity, price, "GTC") do
    fake_order = %{generate_fake_order(symbol, quantity, price) | :side => "BUY"}

    Hefty.Streaming.Backtester.SimpleStreamer.add_order(fake_order)

    GenServer.cast(
      __MODULE__,
      {:add_order, fake_order}
    )

    {:ok, fake_order}
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

    {:ok, fake_order}
  end

  def get_order(symbol, time, order_id) do
    GenServer.call(__MODULE__, {:get_order, symbol, time, order_id})
  end

  defp generate_fake_order(symbol, quantity, price) do
    current_timestamp = :os.system_time(:millisecond)
    order_id = :rand.uniform(1_000_000)

    Binance.OrderResponse.new(%{
      client_order_id: :crypto.hash(:md5, "#{order_id}") |> Base.encode16(),
      executed_qty: "0.00000",
      order_id: order_id,
      orig_qty: Float.to_string(quantity),
      price: Float.to_string(price),
      status: "NEW",
      symbol: symbol,
      time_in_force: "GTC",
      transact_time: current_timestamp,
      type: "LIMIT"
    })
  end

  def handle_cast(
        {:add_order, order},
        %State{:orders => orders, :subscriptions => subscriptions} = state
      ) do
    new_subscriptions =
      case Enum.find(subscriptions, nil, &(&1 == order.symbol)) do
        nil ->
          Logger.debug("BinanceMock subscribing to #{"stream-#{order.symbol}"}")
          :ok = UiWeb.Endpoint.subscribe("stream-#{order.symbol}")
          [order.symbol | subscriptions]

        _ ->
          subscriptions
      end

    {:noreply, %{state | :orders => [order | orders], :subscriptions => new_subscriptions}}
  end

  def handle_call({:get_order, symbol, time, order_id}, _from, %State{:orders => orders} = state) do
    result =
      orders
      |> Enum.find(
        nil,
        &(&1.symbol == symbol and &1.transact_time == time and &1.order_id == order_id)
      )

    {:reply, {:ok, result}, state}
  end

  def handle_info(
        %{
          event: "trade_event",
          payload: %Hefty.Repo.Binance.TradeEvent{:seller_order_id => order_id}
        },
        %State{} = state
      ) do
    update_orders(state, order_id)
  end

  def handle_info(
        %{
          event: "trade_event",
          payload: %Hefty.Repo.Binance.TradeEvent{:buyer_order_id => order_id}
        },
        %State{} = state
      ) do
    update_orders(state, order_id)
  end

  defp update_orders(%State{:orders => orders} = state, order_id) do
    case Enum.find(orders, nil, &(&1.order_id == order_id)) do
      nil ->
        {:noreply, state}

      order ->
        Logger.debug("BinanceMock received trade event for fake order - updating order")
        new_orders = Enum.reject(orders, &(&1.order_id == order_id))
        # hack - assuming that one fake trade will fill whole order here - simplification
        new_order = %{order | :executed_qty => order.orig_qty}
        {:noreply, %{state | :orders => [new_order | new_orders]}}
    end
  end
end
