defmodule UiWeb.SettingsLive do
  use Phoenix.LiveView
  require Logger

  def render(assigns) do
    ~L"""
    <div class="row">
    <div class="col-xs-12">
      <div class="box">
        <div class="box-header">
          <h3 class="box-title">Streaming settings</h3>

          <div class="box-tools">
            <div class="input-group input-group-sm" style="width: 150px;">
              <input type="text" name="table_search" class="form-control pull-right" placeholder="Search">

              <div class="input-group-btn">
                <button type="submit" class="btn btn-default"><i class="fa fa-search"></i></button>
              </div>
            </div>
          </div>
        </div>
        <!-- /.box-header -->
        <div class="box-body table-responsive no-padding">
          <table class="table table-hover">
            <tbody><tr>
              <th>Symbol</th>
              <th>Status</th>
            </tr>
            <%= for setting <- Keyword.values(@settings) do %>
            <tr>
              <td><%= setting.symbol %></td>
              <td><a role="button" phx-click="stream-symbol-<%= setting.symbol %>"><span class="label label-<%= enabled_to_class(setting.enabled) %>"><%= enabled_to_text(setting.enabled) %></span></a></td>
            </tr>
            <% end %>
          </tbody></table>
        </div>
        <!-- /.box-body -->
      </div>
      <!-- /.box -->
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
      &(%{&1 | :enabled => !&1.enabled})
    )
    {:noreply, assign(socket, settings: settings)}
  end

  def enabled_to_class(true), do: "success"
  def enabled_to_class(_), do: "danger"

  def enabled_to_text(true), do: "Streaming"
  def enabled_to_text(_), do: "Stopped"
end
