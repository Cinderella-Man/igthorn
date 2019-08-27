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
              <div class="chart-responsive">
                <canvas id="doughnutChart" height="160" width="329" style="width: 329px; height: 160px;"></canvas>
                  <script id="chart-pie">
                    renderDoughnutChart([<%= for l <- @data.chart_data.labels do %>"<%= l %>",<% end %>], '<%= @symbol %>', [<%= for l <- @data.chart_data.data do %>"<%= l %>",<% end %>])
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
          <ul class="nav nav-pills nav-stacked">
            <li><a href="#">United States of America
              <span class="pull-right text-red"><i class="fa fa-angle-down"></i> 12%</span></a></li>
            <li><a href="#">India <span class="pull-right text-green"><i class="fa fa-angle-up"></i> 4%</span></a>
            </li>
            <li><a href="#">China
              <span class="pull-right text-yellow"><i class="fa fa-angle-left"></i> 0%</span></a></li>
          </ul>
        </div>
        <!-- /.footer -->
      </div>
      <div class="info-box bg-green">
        <span class="info-box-icon"><i class="ion ion-ios-heart-outline"></i></span>

        <div class="info-box-content">
          <span class="info-box-text">Mentions</span>
          <span class="info-box-number">92,050</span>

          <div class="progress">
            <div class="progress-bar" style="width: 20%"></div>
          </div>
          <span class="progress-description">
                20% Increase in 30 Days
              </span>
        </div>
        <!-- /.info-box-content -->
      </div>
      <div class="info-box bg-green">
        <span class="info-box-icon"><i class="ion ion-ios-heart-outline"></i></span>

        <div class="info-box-content">
          <span class="info-box-text">Mentions</span>
          <span class="info-box-number">92,050</span>

          <div class="progress">
            <div class="progress-bar" style="width: 20%"></div>
          </div>
          <span class="progress-description">
                20% Increase in 30 Days
              </span>
        </div>
        <!-- /.info-box-content -->
      </div>
      <div class="info-box bg-green">
        <span class="info-box-icon"><i class="ion ion-ios-heart-outline"></i></span>

        <div class="info-box-content">
          <span class="info-box-text">Mentions</span>
          <span class="info-box-number">92,050</span>

          <div class="progress">
            <div class="progress-bar" style="width: 20%"></div>
          </div>
          <span class="progress-description">
                20% Increase in 30 Days
              </span>
        </div>
        <!-- /.info-box-content -->
      </div>
    """
  end

  def mount(%{}, socket) do
    symbols =
      Hefty.Streams.fetch_streaming_symbols()
      |> Map.keys()

    symbol =
      symbols
      |> List.first()

    {:ok, assign(socket, data: get_data(symbol, symbols), symbol: symbol)}
  end

  def handle_info(%{event: "trade_event"}, socket) do
    {:noreply, socket}
  end

  defp get_data(symbol, symbols) do
    [from, to] = Hefty.Utils.Datetime.get_timestamps(T.today())

    %{
      :chart_data => gaining_losing_data(symbol, from, to),
      :symbols_data => symbols_data(symbols)
    }
  end

  defp gaining_losing_data(symbol, from, to) do
    %{:rows => [[gaining]]} = Hefty.Trades.count_gaining(symbol, from, to)
    %{:rows => [[losing]]} = Hefty.Trades.count_losing(symbol, from, to)

    %{
      :labels => [gaining, losing],
      :data => [gaining, losing],
    }
  end

  defp symbols_data(symbols) do
    
  end
end