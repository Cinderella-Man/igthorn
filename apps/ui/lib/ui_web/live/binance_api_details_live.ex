defmodule UiWeb.BinanceApiDetails do
  @moduledoc false

  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
      <div class="box box-primary">
        <div class="box-header with-border">
          <h3 class="box-title">Binance api details</h3>
        </div>
        <!-- /.box-header -->
        <!-- form start -->
        <form role="form" phx-submit="binance_api_update">
          <div class="box-body">
            <div class="form-group">
              <label for="api_key">Api key</label>
              <input type="input" class="form-control" name="api_key" id="api_key" value="<%= @api_key %>" placeholder="Api key">
            </div>
            <div class="form-group">
              <label for="secret_key">Secret key</label>
              <input type="password" class="form-control" name="secret_key" id="secret_key" value="<%= @secret_key %>" placeholder="Secret key">
            </div>
          </div>
          <!-- /.box-body -->

          <div class="box-footer">
            <button type="submit" class="btn btn-primary pull-right">Update</button>
          </div>
        </form>
      </div>
    """
  end

  def mount(%{}, socket) do
    details = Hefty.Settings.fetch_binance_api_details()
    {:ok, assign(socket, api_key: details.api_key, secret_key: "")}
  end

  def handle_event(
        "binance_api_update",
        %{"api_key" => api_key, "secret_key" => secret_key},
        socket
      ) do
    Hefty.Settings.update_binance_api_details(api_key, secret_key)
    {:noreply, assign(socket, api_key: api_key, secret_key: "")}
  end
end
