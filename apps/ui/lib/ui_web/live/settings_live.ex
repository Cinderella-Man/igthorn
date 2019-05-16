defmodule UiWeb.SettingsLive do
  use Phoenix.LiveView
  require Logger

  def render(assigns) do
    ~L"""
    <div class="">
      <div>
        <table>
          <tr>
            <th>Symbol</th>
            <th>Budget</th>
            <th>Profit Interval</th>
            <th>Buy Down Interval</th>
            <th>Chunks</th>
            <th><a phx-click="stream-all" href="#">Is streaming?</a></th>
            <th><a phx-click="trade-all" href="#">Is trading?</a></th>
          </tr>
          <%= for setting <- Keyword.values(@settings) do %>
            <tr>
                <td><%= setting.symbol %></td>
                <td><%= setting.budget %></td>
                <td><%= setting.profit_interval %></td>
                <td><%= setting.buy_down_interval %></td>
                <td><%= setting.chunks %></td>
                <td><a href="#" phx-click="stream-symbol-<%= setting.symbol %>"><%= setting.streaming %></a></td>
                <td><a href="#" phx-click="trade-symbol-<%= setting.symbol %>"><%= setting.trading %></a></td>
            </tr>
          <% end %>
        </table>
      </div>
    </div>
    """
  end

  def mount(%{settings: settings}, socket) do
    {:ok, assign(socket, settings: settings)}
  end

  def handle_event("stream-symbol-" <> symbol, _, socket) do
    Logger.info("Flipping streaming of " <> symbol, [entity: "SettingLive"])
    Hefty.flip_streamer(symbol)

    settings = Keyword.update!(
      socket.assigns.settings,
      :"#{symbol}",
      &(%{&1 | :streaming => !&1.streaming})
    )
    {:noreply, assign(socket, settings: settings)}
  end

  def handle_event("stream-all", _, socket) do
    Logger.info("Flipping streaming of all symbols", [entity: "SettingLive"])
    socket.assigns.settings
      |> Enum.map(&(&1.symbol))
      |> Enum.map(&(Hefty.flip_streamer(&1)))
    {:noreply, assign(socket, stream: "all")}
  end

  def handle_event("trade-symbol-" <> symbol, _, socket) do
    Logger.info("Flipping trading of " <> symbol, [entity: "SettingLive"])
    Hefty.flip_trader(symbol)
    {:noreply, assign(socket, trade: symbol)}
  end
end
