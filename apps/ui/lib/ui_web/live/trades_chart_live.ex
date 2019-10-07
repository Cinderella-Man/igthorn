defmodule UiWeb.TradesChartLive do
  use Phoenix.LiveView
  use Phoenix.HTML

  def render(assigns) do
    ~L"""
    <div class="box box-info">
      <div class="box-header with-border">
        <h3 class="box-title">Latest Orders</h3>

        <div class="box-tools pull-right">
          <button type="button" class="btn btn-box-tool" data-widget="collapse"><i class="fa fa-minus"></i>
          </button>
          <button type="button" class="btn btn-box-tool" data-widget="remove"><i class="fa fa-times"></i></button>
        </div>
      </div>
      <!-- /.box-header -->
      <div class="box-body">
        <div class="row">
          <%= if length(@symbols) > 0 do %>
            <div class="col-xs-2">
              <form phx-change="change-symbol" id="change-symbol">
                <select name="selected_symbol" class="form-control">
                  <%= for row <- @symbols do %>
                    <option value="<%= row %>"
                    <%= if row == @symbol do %>
                      selected
                    <% end %>
                    ><%= row %></option>
                  <% end %>
                </select>
              </form>
            </div>
          <% end %>
        </div><br>
        <div class="chart">
          <canvas id="barChart" style="display: block; width: 1000px!important; height: 400px; margin: auto;" width="1000" height="400"></canvas>
          <script id="chart<%= Base.encode64(:erlang.md5(@symbol)) %>">
            renderBarChart(
              [<%= for s <- get_active_symbols(@symbol, @symbols) do %>"<%= s %>",<% end %>],
              <%= raw(get_active_values(@symbol, @symbols)) %>
            )
          </script>
        </div>
      </div>
      <!-- /.box-body -->
    </div>
    """
  end

  def mount(%{}, socket) do
    symbols = ["ALL" | Hefty.Trades.get_all_trading_symbols()]

    {:ok, assign(socket, data: get_data(), symbol: "ALL", symbols: symbols)}
  end

  def handle_event("change-symbol", %{"selected_symbol" => selected_symbol}, socket) do
    {:noreply,
     assign(socket,
       symbol: selected_symbol,
       data: socket.assigns.data,
       symbols: socket.assigns.symbols
     )}
  end

  defp get_data() do
    []
  end

  defp get_active_symbols("ALL", symbols) do
    symbols |> Enum.filter(&(&1 !== "ALL"))
  end

  defp get_active_symbols(symbol, _symbols), do: [symbol]

  defp get_active_values("ALL", symbols) do
    Hefty.Trades.count_trades_by_symbol(get_active_symbols("ALL", symbols))

    JSON.encode!(
      labels: Hefty.Utils.Datetime.get_last_days(30),
      values: Hefty.Trades.count_trades_by_symbol(get_active_symbols("ALL", symbols))
    )
  end

  defp get_active_values(symbol, symbols) do
    JSON.encode!(
      labels: Hefty.Utils.Datetime.get_last_days(30),
      values: Hefty.Trades.count_trades_by_symbol(get_active_symbols(symbol, symbols))
    )
  end
end
