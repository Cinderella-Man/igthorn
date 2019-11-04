defmodule UiWeb.SettingsLive do
  @moduledoc false

  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
      <div class="row">
        <div class="col-md-4">
          <%= live_render(@socket, UiWeb.BinanceApiDetails) %>
        </div>
      </div>
    """
  end

  def mount(%{}, socket) do
    {:ok, socket}
  end
end
