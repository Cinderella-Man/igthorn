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

  ## Public interface

  def get_account() do
    Binance.get_account()
  end

  def get_exchange_info() do
    Binance.get_exchange_info()
  end

  @spec order_limit_buy(String.t(), float(), float(), String.t()) ::
          {:ok, %Binance.OrderResponse{}}
  def order_limit_buy(symbol, quantity, price, "GTC") do
    order_limit(symbol, quantity, price, "BUY")
  end

  def order_limit_sell(symbol, quantity, price, "GTC") do
    order_limit(symbol, quantity, price, "SELL")
  end

  def order_market_sell(symbol, quantity) do
    order_limit_sell(symbol, quantity, 0.0, "GTC")
  end

  def get_order(symbol, time, order_id) do
    GenServer.call(__MODULE__, {:get_order, symbol, time, order_id})
  end

  def cancel_order(
        symbol,
        timestamp,
        order_id,
        _orig_client_order_id \\ nil,
        _new_client_order_id \\ nil,
        _recv_window \\ nil
      ) do
    GenServer.call(__MODULE__, {:cancel_order, symbol, timestamp, order_id})
  end

  ## Callbacks

  def handle_cast(
        {:add_order, %Binance.OrderResponse{:symbol => symbol} = order_response},
        %State{:orders => orders, :subscriptions => subscriptions} = state
      ) do
    new_subscriptions =
      case Enum.find(subscriptions, nil, &(&1 == symbol)) do
        nil ->
          Logger.debug("BinanceMock subscribing to #{"stream-#{symbol}"}")
          :ok = UiWeb.Endpoint.subscribe("stream-#{symbol}")
          [symbol | subscriptions]

        _ ->
          subscriptions
      end

    order = convert_order_response_to_order(order_response)

    {:noreply, %{state | :orders => [order | orders], :subscriptions => new_subscriptions}}
  end

  def handle_call({:get_order, symbol, time, order_id}, _from, %State{:orders => orders} = state) do
    result =
      orders
      |> Enum.find(
        nil,
        &(&1.symbol == symbol and &1.time == time and &1.order_id == order_id)
      )

    {:reply, {:ok, result}, state}
  end

  def handle_call(
        {:cancel_order, symbol, timestamp, order_id},
        _from,
        %State{:orders => orders} = state
      ) do
    index =
      orders
      |> Enum.find_index(
        &(&1.symbol == symbol and &1.time == timestamp and &1.order_id == order_id)
      )

    case index do
      nil ->
        Logger.error("Unable to find requested order to be canceled")
        {:reply, {:error, :not_found}, state}

      _ ->
        {order, rest_of_orders} = List.pop_at(orders, index)
        {:reply, {:ok, %{order | :status => "CANCELED"}}, %{state | :orders => rest_of_orders}}
    end
  end

  def handle_info(
        %{
          event: "trade_event",
          payload: %Hefty.Repo.Binance.TradeEvent{
            :buyer_order_id => buyer_order_id,
            :seller_order_id => seller_order_id,
            :price => price
          }
        },
        %State{orders: orders} = state
      ) do
    case Enum.find(
           orders,
           nil,
           &(&1.order_id == buyer_order_id || &1.order_id == seller_order_id)
         ) do
      nil ->
        {:noreply, state}

      order ->
        Logger.debug("BinanceMock received trade event for fake order - updating order")
        new_orders = Enum.reject(orders, &(&1.order_id == order.order_id))
        # hack - assuming that one fake trade will fill whole order here - simplification
        # price is overriden for market orders
        new_order = %{order | :executed_qty => order.orig_qty, :price => price, status: "FILLED"}
        {:noreply, %{state | :orders => [new_order | new_orders]}}
    end
  end

  ## Helpers

  defp order_limit(symbol, quantity, price, side) do
    fake_order = %{generate_fake_order(symbol, quantity, price) | :side => side}

    Hefty.Streaming.Backtester.SimpleStreamer.add_order(fake_order)

    GenServer.cast(
      __MODULE__,
      {:add_order, fake_order}
    )

    {:ok, fake_order}
  end

  defp generate_fake_order(symbol, quantity, price)
       when is_binary(symbol) and is_float(quantity) and is_float(price) do
    current_timestamp = :os.system_time(:millisecond)
    order_id = current_timestamp

    Binance.OrderResponse.new(%{
      client_order_id: :crypto.hash(:md5, "#{order_id}") |> Base.encode16(),
      executed_qty: "0.00000000",
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

  defp convert_order_response_to_order(order_response) do
    Binance.Order.new(%{
      symbol: order_response.symbol,
      order_id: order_response.order_id,
      client_order_id: order_response.client_order_id,
      price: order_response.price,
      orig_qty: order_response.orig_qty,
      executed_qty: order_response.executed_qty,
      # not sure here..
      cummulative_quote_qty: order_response.executed_qty,
      status: order_response.status,
      time_in_force: order_response.time_in_force,
      type: order_response.type,
      side: order_response.side,
      stop_price: nil,
      iceberg_qty: nil,
      time: order_response.transact_time,
      # not sure here..
      update_time: order_response.transact_time,
      # not sure here..
      is_working: true
    })
  end
end
