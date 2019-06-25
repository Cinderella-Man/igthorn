defmodule UiWeb.DashboardLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div class="">
      Current prices of streamed symbol

      <%= live_render(@socket, UiWeb.PriceFeedLive) %>
      <%= live_render(@socket, UiWeb.PriceChartLive) %>
    </div>
    """
  end

  def mount(%{}, socket) do
    {:ok, socket}
  end
end
