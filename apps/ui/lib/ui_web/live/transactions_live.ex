defmodule UiWeb.TransactionsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
      <%= if length(@transactions_data.list) >= 0 do %>
      <div class="row">
        <div class="col-xs-12">
          <div class="box">
            <div class="box-header">
              <h3 class="box-title">Orders</h3>
              <div class="box-tools">
                <form phx-change="search" phx-submit="search" id="search">
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
              <div class="box-body">
                <form phx-change="rows" phx-submit="rows">
                  <div class="input-group input-group-sm col-xs-1">
                    <select class="form-control" name="rows_per_page">
                      <%= for row <- @rows_numbers do %>
                        <option value="<%= row %>"
                        <%= if row == @set_rows do %>
                          selected
                        <% end %>
                        ><%= row %></option>
                      <% end %>
                    </select>
                    <span class="input-group-btn">
                      <button type="submit" class="btn btn-info btn-flat">Rows</button>
                    </span>
                  </div>
                </form>
              </div>
              <br>
              <table class="table table-hover">
                <thead>
                  <tr>
                    <th>Symbol</th>
                    <th>Price</th>
                    <th>Quantity</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for transaction <- @transactions_data.list do %>
                    <tr>
                      <td><%= transaction.symbol %></td>
                      <td><%= transaction.price %></td>
                      <td><%= transaction.quantity %></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
            <div class="box-footer clearfix">
              <span><%= @transactions_data.total %> row<%= if @transactions_data.total != 1 do %>s<% end %></span>
              <%= if show_pagination?(@transactions_data.limit, @transactions_data.total) do %>
                <ul class="pagination pagination-sm no-margin pull-right">
                  <li><a phx-click="pagination-1" href="#">«</a></li>
                  <%= for link <- @transactions_data.pagination_links do %>
                    <li <%= if link == @transactions_data.page do %>
                        class="active"
                      <% end %>
                    >
                      <a phx-click="pagination-<%= link %>" href="#"><%= link %></a>
                    </li>
                  <% end %>
                  <li><a phx-click="pagination-<%= @orders_data.pages %>" href="#">»</a></li>
                </ul>
              <% end %>
            </div>
          </div>
        </div>
      </div>
      <% else %>
        You are not have any transactions
      <% end %>
    """
  end

  def mount(%{}, socket) do

    IO.inspect(transactions_data(50, 1, ""))

    {:ok,
      assign(socket,
      transactions_data: transactions_data(50, 1, ""),
      rows_numbers: [10, 20, 30, 40, 50, 100, 200],
      set_rows: 50,
      search: ""
    )}
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
      assign(socket,
        transactions_data: transactions_data(50, 1, search),
        rows_numbers: [10, 20, 30, 40, 50, 100, 200],
        set_rows: socket.assigns.set_rows,
        search: search
      )}
  end

   def handle_event("rows", %{"rows_per_page" => limit}, socket) do
     IO.inspect(limit)
    {:noreply,
     assign(socket,
      transactions_data: transactions_data(String.to_integer(limit), 1, socket.assigns.search),
      rows_numbers: [10, 20, 30, 40, 50, 100, 200],
      set_rows: String.to_integer(limit),
      search: socket.assigns.search
     )}
  end

  def handle_event("pagination-" <> page, _, socket) do
    {:noreply,
      assign(socket,
        transactions_data:
          transactions_data(
            socket.assigns.orders_data.limit,
            String.to_integer(page),
            socket.assigns.search
          ),
        rows_numbers: [10, 20, 30, 40, 50, 100, 200],
        set_rows: socket.assigns.set_rows,
        search: socket.assigns.search
      )}
  end

  defp transactions_data(limit, page, search) do
    transactions = Hefty.fetch_transactions((page - 1) * limit, limit, search)

    all = Hefty.count_transactions(search)

    pagination_links =
      Enum.filter(
        (page - 3)..(page + 3),
        &(&1 >= 1 and &1 <= round(Float.ceil(all / limit)))
      )

    %{
      :list => transactions,
      :total => all,
      :pages => round(Float.ceil(all / limit)),
      :pagination_links => pagination_links,
      :page => page,
      :limit => limit
    }
  end

  defp show_pagination?(limit, total), do: limit < total
end