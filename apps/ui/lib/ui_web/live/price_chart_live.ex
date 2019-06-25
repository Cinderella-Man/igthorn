defmodule UiWeb.PriceChartLive do
  use Phoenix.LiveView
  alias Timex, as: T

  def render(assigns) do
    ~L"""
      <%= if not is_nil(@data.symbol) do %>
        <div class="row">
          <div class="col-md-12">
            <!-- AREA CHART -->
            <div class="box box-primary">
              <div class="box-header with-border">
                <h3 class="box-title">
                  <form phx-change="change-symbol" id="change-symbol">
                    <select name="selected_symbol" class="form-control">
                      <%= for row <- @symbols do %>
                        <option value="<%= row %>"
                        <%= if row == @data.symbol do %>
                          selected
                        <% end %>
                        ><%= row %></option>
                      <% end %>
                    </select>
                  </form>
                </h3>
              </div>
              <div class="box-body">
                <div class="chart">
                  <script src="/dist/js/chart.js"></script>
                  <canvas id="lineChart" style="height: 300; width: 1400;" width="1400" height="300"></canvas>
                  <script id="chart-<%= Base.encode64(:erlang.md5(@data.prices)) %>">
                    renderChart([<%= for l <- @data.labels do %>"<%= l %>",<% end %>], "<%= @data.symbol %>", <%= @data.prices %>)
                  </script>
                </div>
              </div>
              <!-- /.box-body -->
            </div>
            <!-- /.box -->
          </div>
        </div>
      <% end %>
    """
  end

  def mount(%{}, socket) do
    symbols = Hefty.fetch_streaming_symbols()
              |> Map.keys
    symbol = symbols
             |> List.first
    symbols
      |> Enum.map(&UiWeb.Endpoint.subscribe("stream-#{&1}"))

    {:ok, assign(socket, data: price_chart_data(symbol), symbols: symbols)}
  end

  def handle_info(%{event: "trade_event", payload: event}, socket) do
    {:noreply, assign(socket, data: price_chart_data(socket.assigns.data.symbol), symbols: socket.assigns.symbols)}
  end

  defp price_chart_data(symbol) when is_nil(symbol), do: %{:symbol => nil}

  def handle_event("change-symbol", %{"selected_symbol" => selected_symbol}, socket) do
    {:noreply, assign(socket, data: price_chart_data(selected_symbol), symbols: socket.assigns.symbols)}
  end


  defp price_chart_data(symbol) do
    data = Hefty.fetch_trade_events_prices(symbol)
    prices = data
             |> Enum.map(&List.first/1)
             |> Enum.reverse
             |> Enum.map(&String.to_float/1)
             |> Jason.encode!

    labels = data
             |> Enum.map(&List.last/1)
             |> Enum.reverse
             |> Enum.map(&T.format!(&1, "{h24}:{0m}:{0s}"))

    %{
      :labels => labels,
      :symbol => symbol,
      :prices => prices
    }
  end
end