defmodule Hefty.Exchanges.BinanceMock do
  def get_account() do
    Binance.get_account()
  end

  def get_exchange_info() do
    Binance.get_exchange_info()
  end
end
