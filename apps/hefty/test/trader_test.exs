defmodule HeftyTest do
  use ExUnit.Case
  doctest Hefty

  test "greets the world" do
    assert Hefty.hello() == :world
  end
end
