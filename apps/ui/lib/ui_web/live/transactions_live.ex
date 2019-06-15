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
              <form phx_change="search" phx-submit="search">
                <div class="input-group input-group-sm" style="width: 180px;">
                  <input type="text" name="search" class="form-control pull-right" placeholder="Search" value="<%= @search %>">
                  <div class="input-group-btn">
                    <button type="submit" class="btn btn-default"><i class="fa fa-search"></i></button>
                  </div>
                </div>
              </form>
            </div>
          </div>
          <!-- /.box-header -->
          <div class="box-body table-responsive no-padding">
            <%= if length(@transactions_data.list) > 0 do %>
              <table class="table table-hover">
                <thead>
                  <tr>
                    <th>Symbol</th>
                    <th>Price</th>
                    <th>Quantity</th>
                    <th>Commission</th>
                    <th>Commission asset</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for row <- Keyword.values(@transactions_data.list) do %>
                    <tr>
                      <td></td>
                      <td></td>
                      <td></td>
                      <td></td>
                      <td></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
              <div class="box-footer clearfix">
                <span><%= @transactions_data.total %> rows</span>
                <%= if show_pagination?(@transactions_data.limit, @transactions_data.total) do %>
                  <ul class="pagination pagination-sm no-margin pull-right">
                    <li><a phx-click="pagination-1" href="#">«</a></li>
                    <%= for link <- @naive_trader_settings_data.pagination_links do %>
                      <li <%= if link == @naive_trader_settings_data.page do %>
                          class="active"
                        <% end %>
                      >
                        <a phx-click="pagination-<%= link %>" href="#"><%= link %></a>
                      </li>
                    <% end %>
                    <li><a phx-click="pagination-<%= @naive_trader_settings_data.pages %>" href="#">»</a></li>
                  </ul>
                <% end %>
              </div>
            <% else %>
              <div class="box-body">
               Nothing to display
              </div>
            <% end %>
          </div>
          <!-- /.box-body -->
        </div>
        <!-- /.box -->
      </div>
    </div>
    """
  end

  def mount(_session, socket) do
    IO.inspect(transactions_data(10, 1))
    {:ok,
     assign(socket,
       transactions_data: transactions_data(10, 1),
       search: ""
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

  def handle_event("search", %{"search" => search}, socket) do
    {
      :noreply,
      socket
    }
  end

  defp show_pagination?(limit, total), do: limit < total
end
