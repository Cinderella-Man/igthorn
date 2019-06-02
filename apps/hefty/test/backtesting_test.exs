defmodule BacktestingTest do
  use ExUnit.Case
  doctest Hefty

  alias Hefty.Streaming.Backtester.{SimpleStreamer, DbStreamer}

  test "Running backtesting" do
    # First start start simply streamer process
    {:ok, streamer_pid} = SimpleStreamer.start_link()
    SimpleStreamer.start_streaming(streamer_pid, "BNBBTC", "2019-06-02", "2019-06-02", 500)

    assert_receive :stream_finished, 15000
    # assert Hefty.hello() == :world
  end
end
