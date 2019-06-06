defmodule UiWeb.BacktestingLive do
  use Phoenix.LiveView
  require Logger

  def render(assigns) do
    ~L"""
    <div class="box box-primary">
    <div class="box-header with-border">
      <h3 class="box-title">Run historical data</h3>
    </div>
    <!-- /.box-header -->
    <!-- form start -->
    <form role="form" phx-submit="kick-off-backtesting">
      <div class="box-body">

        <div class="form-group">
          <label>Symbol</label>
          <select class="form-control select2" style="width: 100%;" name="symbol">
            <%= for symbol <- @symbols do %>
              <option><%= symbol.symbol %></option>
            <% end %>
          </select>
        </div>

        <!-- Date range -->
          <div class="form-group">
          <label>Date range:</label>

          <div class="input-group">
            <div class="input-group-addon">
              <i class="fa fa-calendar"></i>
            </div>
            <input type="text" class="form-control pull-right" name="date-range" id="date-range">
          </div>
          <!-- /.input group -->
        </div>
        <!-- /.form group -->



      </div>
      <!-- /.box-body -->

      <div class="box-footer">
        <button type="submit" class="btn btn-primary">Submit</button>
      </div>
    </form>
    </div>

    <script>
      setTimeout(function () {
        console.log("Called");
        //Initialize Select2 Elements
        $('.select2').select2()

        //Date range picker
        $('#date-range').daterangepicker({
          locale: {
            format: 'YYYY-MM-DD'
          }
        })
      }, 1000)
    </script>
    """
  end

  def mount(%{}, socket) do
    {:ok, assign(socket, symbols: Hefty.fetch_symbols())}
  end

  def handle_event(
        "kick-off-backtesting",
        %{"symbol" => symbol, "date-range" => date_range},
        socket
      ) do
    [from_date, to_date] = convert_daterange_to_dates(date_range)
    Hefty.Backtesting.kick_off_backtesting(symbol, from_date, to_date)
    {:noreply, socket}
  end

  defp convert_daterange_to_dates(daterange) do
    [_from, _to] = String.split(daterange, " - ")
  end
end
