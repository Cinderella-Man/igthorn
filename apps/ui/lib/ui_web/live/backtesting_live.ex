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
          <select class="form-control select2 select2-hidden-accessible" name="symbol" style="width: 100%;" tabindex="-1" aria-hidden="true">
            <option selected="selected">Alabama</option>
            <option>Alaska</option>
            <option>California</option>
            <option>Delaware</option>
            <option>Tennessee</option>
            <option>Texas</option>
            <option>Washington</option>
          </select>
        </div>


        <div class="form-group">
          <label>From:</label>

          <div class="input-group">
            <div class="input-group-addon">
              <i class="fa fa-calendar"></i>
            </div>
            <input type="text" name="from" class="form-control" data-inputmask="'alias': 'dd/mm/yyyy'" data-mask="">
          </div>
          <!-- /.input group -->
        </div>

        <div class="form-group">
          <label>To(inclusive):</label>

          <div class="input-group">
            <div class="input-group-addon">
              <i class="fa fa-calendar"></i>
            </div>
            <input type="text" name="to" class="form-control" data-inputmask="'alias': 'dd/mm/yyyy'" data-mask="">
          </div>
          <!-- /.input group -->
        </div>



      </div>
      <!-- /.box-body -->

      <div class="box-footer">
        <button type="submit" class="btn btn-primary">Submit</button>
      </div>
    </form>
    </div>
    """
  end

  def mount(%{}, socket) do
    {:ok, socket}
  end
end
