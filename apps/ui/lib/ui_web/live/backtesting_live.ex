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
    <form role="form">
      <div class="box-body">

        <div class="form-group">
          <label>Symbol</label>
          <select class="form-control select2" style="width: 100%;">
            <option selected="selected">Alabama</option>
            <option>Alaska</option>
            <option>California</option>
            <option>Delaware</option>
            <option>Tennessee</option>
            <option>Texas</option>
            <option>Washington</option>
          </select>
        </div>

        <!-- Date range -->
          <div class="form-group">
          <label>Date range:</label>

          <div class="input-group">
            <div class="input-group-addon">
              <i class="fa fa-calendar"></i>
            </div>
            <input type="text" class="form-control pull-right" id="date-range">
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
        $('#date-range').daterangepicker()
      }, 1000)
    </script>
    """
  end

  def mount(%{}, socket) do
    {:ok, socket}
  end
end
