defmodule Hefty.Exchanges.BinanceMock do
  def get_account() do
    Binance.get_account()
  end

  def get_exchange_info() do
    Binance.get_exchange_info()
  end

  def order_limit_buy(symbol, quantity, price, "GTC") do
    fake_order = %{generate_fake_order(symbol, quantity, price) | side => "BUY"}

    GenServer.cast(
      Hefty.Streaming.Backtester.SimpleStreamer,
      {:order, fake_order}
    )

    fake_order
  end

  def order_limit_sell(symbol, quantity, price, "GTC") do
    fake_order = %{generate_fake_order(symbol, quantity, price) | side => "SELL"}

    GenServer.cast(
      Hefty.Streaming.Backtester.SimpleStreamer,
      {:order, fake_order}
    )

    fake_order
  end

  def get_order(symbol, time, order_id) do

  end

  defp generate_fake_order(symbol, quantity, price) do
    current_timestamp = :os.system_time(:millisecond)
    order_id = :rand.uniform(1000000)

    %Binance.OrderResponse.new(%{
      client_order_id => (:crypto.hash(:md5, order_id) |> Base.encode16()),
      executed_qty => "0.00000",
      order_id => order_id,
      orig_qty => quantity,
      price => Float.to_string(price),
      status => "NEW",
      symbol => symbol,
      time_in_force => "GTC",
      transact_time => current_timestamp,
      type => "LIMIT"
    })
  end
end
