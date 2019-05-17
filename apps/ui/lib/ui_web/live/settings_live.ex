defmodule UiWeb.SettingsLive do
  use Phoenix.LiveView
  require Logger

  def render(assigns) do
    ~L"""
      <table id="example2" class="table table-bordered table-hover dataTable" role="grid" aria-describedby="example2_info">
        <thead>
          <tr role="row">
            <th class="sorting_asc" tabindex="0" aria-controls="example2" rowspan="1" colspan="1" aria-sort="ascending" aria-label="Rendering engine: activate to sort column descending">Symbol</th>
            <th class="sorting" tabindex="0" aria-controls="example2" rowspan="1" colspan="1" aria-label="Browser: activate to sort column ascending">Streaming enabled</th>
          </tr>
        </thead>
        <tbody>
          <%= for setting <- Keyword.values(@settings) do %>
            <tr role="row" class="odd">
              <td class="sorting_1"><%= setting.symbol %></td>
              <td><a phx-click="stream-symbol-<%= setting.symbol %>"><i class="fa fa-<%= convert_to_symbol(setting.enabled) %>"></i></a></td>
            </tr>
          <% end %>
        </tbody>
        <tfoot>
          <tr>
            <th rowspan="1" colspan="1">Symbol</th>
            <th rowspan="1" colspan="1">Streaming enabled</th>
          </tr>
        </tfoot>
      </table>
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
      &(%{&1 | :enabled => !&1.enabled})
    )
    {:noreply, assign(socket, settings: settings)}
  end

  def convert_to_symbol(true), do: "check"
  def convert_to_symbol(_), do: "times"
end
