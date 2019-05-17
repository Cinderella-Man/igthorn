defmodule UiWeb.PriceFeedLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div class="">
      Works price_feed_live
    </div>
    """
  end

  def mount(%{}, socket) do

    IO.inspect("getting here")

    Hefty.fetch_streaming_symbols()
        |> Enum.map(&(elem(&1, 1)))
        |> Enum.map(&(Hefty.Streaming.Streamer.subscribe(&1)))
    {:ok, socket}
  end

  def handle_info(a, socket) do
    IO.inspect(a, label: "works")
    IO.inspect(self())
    {:noreply, socket}
  end
end
