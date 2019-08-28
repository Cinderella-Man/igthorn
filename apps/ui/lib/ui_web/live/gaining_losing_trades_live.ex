defmodule UiWeb.GainingLosingTradesLive do
  use Phoenix.LiveView
  alias Timex, as: T

  def render(assigns) do
    ~L"""
      <div class="box box-success">
        <div class="box-header with-border">
          <h3 class="box-title">Gaining / Losing - <%= @symbol %></h3>

          <div class="box-tools pull-right">
            <button type="button" class="btn btn-box-tool" data-widget="collapse"><i class="fa fa-minus"></i>
            </button>
            <button type="button" class="btn btn-box-tool" data-widget="remove"><i class="fa fa-times"></i></button>
          </div>
        </div>
        <!-- /.box-header -->
        <div class="box-body" style="">
          <div class="row">
            <div class="col-md-8">
              <%= if length(@data.symbols) > 0 do %>
                <div class="col-xs-5">
                  <form phx-change="change-symbol" id="change-symbol">
                    <select name="selected_symbol" class="form-control col-xs-3">
                      <%= for row <- @data.symbols do %>
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
              <div class="chart-responsive">
                <canvas id="doughnutChart" height="160" width="329" style="width: 329px; height: 160px;"></canvas>
                  <script id="chart-<%= Base.encode64(:erlang.md5(@symbol)) %>">
                    renderDoughnutChart([<%= for l <- get_chart_data(@data.chart_data.rows, @symbol) do %>"<%= l %>",<% end %>])
                  </script>
              </div>
              <!-- ./chart-responsive -->
            </div>
            <!-- /.col -->
            <div class="col-md-4">
              <ul class="chart-legend clearfix">
                <li><i class="fa fa-circle-o text-green"></i> Gaining</li>
                <li><i class="fa fa-circle-o text-red"></i> Losing</li>
              </ul>
            </div>
            <!-- /.col -->
          </div>
          <!-- /.row -->
        </div>
        <!-- /.box-body -->
        <div class="box-footer no-padding" style="">
        </div>
        <!-- /.footer -->
      </div>
    """
  end

  def mount(%{}, socket) do
    [from, to] = Hefty.Utils.Datetime.get_timestamps(T.today())

    symbols =
      Hefty.Trades.fetch_trading_symbols(from, to)
      |> Enum.map(&List.to_string(&1))

    symbol =
      symbols
      |> List.first()

    {:ok, assign(socket, data: get_data(symbols), symbol: symbol)}
  end

  def handle_info(%{event: "trade_event"}, socket) do
    {:noreply, socket}
  end

  def handle_event("change-symbol", %{"selected_symbol" => selected_symbol}, socket) do
    {:noreply, assign(socket,
      symbol: selected_symbol,
      data: socket.assigns.data
    )}
  end

  defp get_data(symbols) do
    [from, to] = Hefty.Utils.Datetime.get_timestamps(T.today())

    %{
      :chart_data => gaining_losing_data(from, to),
      :symbols => symbols
    }
  end

  defp gaining_losing_data(from, to) do
    rows_data = Hefty.Trades.count_gaining_losing(from, to).rows

    rows = rows_data
    |> Enum.group_by(fn [head | _tail] -> head end)
    |> Enum.map(&row_builder(&1))

    %{
      :rows => rows,
    }
  end

  defp row_builder(row) do
    {symbol, [[_, _, losing], [_, _, gaining]]} = row
    %{String.to_atom("#{symbol}") => [gaining, losing]}
  end

  defp get_chart_data(rows, symbol) do
    row = rows
      |> Enum.filter(fn row -> Map.has_key?(row, String.to_atom(symbol)) end)
      |> List.first
    row[String.to_atom(symbol)]
  end
end