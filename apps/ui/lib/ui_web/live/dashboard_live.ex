defmodule UiWeb.DashboardLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <script src="/dist/js/chart.js"></script>
    <div class="row">
      <div class="col-xs-12">
        <%= live_render(@socket, UiWeb.PriceFeedLive) %>
      </div>
    </div>
    <div class="row">
      <div class="col-md-8">
        <%= live_render(@socket, UiWeb.PriceChartLive) %>
        <%= live_render(@socket, UiWeb.TradesChartLive) %>
      </div>
      <div class="col-md-4">
        <%= live_render(@socket, UiWeb.ProfitIndicatorLive) %>
        <%= live_render(@socket, UiWeb.GainingLosingTradesLive) %>
      </div>
    </div>
    """
  end

  def mount(%{}, socket) do
    {:ok, socket}
  end
end
