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
                  <script id="chart-pie">
                    renderDoughnutChart([<%= for l <- @data.chart_data.rows[:"#{@symbol}"] do %>"<%= l %>",<% end %>], '<%= @symbol %>', [<%= for l <- @data.chart_data.data do %>"<%= l %>",<% end %>])
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
    symbol =
      symbols
      |> List.first()

    {:ok, assign(socket, data: get_data(symbol, symbols), symbol: symbol)}
  end

  def handle_info(%{event: "trade_event"}, socket) do
    {:noreply, socket}
  end

  def handle_event("change-symbol", %{"selected_symbol" => selected_symbol}, socket) do
    {:noreply, socket}
  end

  defp get_data(symbol, symbols) do
    [from, to] = Hefty.Utils.Datetime.get_timestamps(T.today())

    %{
      :chart_data => gaining_losing_data(symbols, from, to),
      :symbols => symbols
    }
  end

  defp gaining_losing_data(symbols, from, to) do
#    %{:rows => [[gaining]]} = Hefty.Trades.count_gaining(symbol, from, to)
#    %{:rows => [[losing]]} = Hefty.Trades.count_losing(symbol, from, to)

    rows = symbols
      |> Enum.map(&%{"#{&1}": Hefty.Trades.count_gaining(&1, from, to)})
      |> Enum.into([], &%{"#{(List.first(Map.keys(&1)))}":
      %{
        :data => [
          Hefty.Trades.count_gaining(List.first(Map.keys(&1)), from, to).rows
            |> List.first
            |> List.first,
          Hefty.Trades.count_losing(List.first(Map.keys(&1)), from, to).rows
            |> List.first
            |> List.first,
        ],
      }
    })

    %{
      :rows => rows,
    }
  end
end