defmodule UiWeb.TransactionsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div class="row">
      <div class="col-xs-12">
        <div class="box">
          <div class="box-header">
            <h3 class="box-title">Transactions</h3>
            <div class="box-tools">
              <form>
                <div class="input-group input-group-sm" style="width: 180px;">
                  <input type="text" name="search" class="form-control pull-right" placeholder="Search">
                  <div class="input-group-btn">
                    <button type="submit" class="btn btn-default"><i class="fa fa-search"></i></button>
                  </div>
                </div>
              </form>
            </div>
          </div>
          <!-- /.box-header -->
          <div class="box-body table-responsive no-padding">
            <form phx_change="save-row" phx-submit="save-row">
              <table class="table table-hover">
                <tbody>
                    <th>Symbol</th>
                  </tbody>
              </table>
            </form>
          </div>
          <!-- /.box-body -->
        </div>
        <!-- /.box -->
      </div>
    </div>
    """
  end

  def mount(_session, socket) do
    {:ok, assign(socket,
      transactions_data: transactions_data(10, 1)
    )}
  end

  defp transactions_data(limit, page) do
    transactions = Hefty.fetch_transactions((page - 1) * limit, limit)
    %{
      :list => transactions,
      :total => length(transactions),
      :limit => limit,
      :page => page
    }
  end
end