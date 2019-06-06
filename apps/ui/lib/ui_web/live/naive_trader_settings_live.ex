defmodule UiWeb.NaiveTraderSettingsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div class="row">
      <div class="col-xs-12">
        <div class="box">
          <div class="box-header">
            <h3 class="box-title">Naive trader settings</h3>
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
          <%= if length(@naive_trader_settings_paginate.list) > 0 do %>
            <div class="box-body table-responsive no-padding">
              <div class="box-body">
                <form phx_change="rows" phx-submit="rows">
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
              <form phx_change="save-row" phx-submit="save-row">
                <table class="table table-hover">
                  <tbody>
                    <th>Symbol</th>
                    <th>Budget</th>
                    <th>Profit Interval</th>
                    <th>Buy Down Interval</th>
                    <th>Chunks</th>
                    <th>Stop Loss Interval</th>
                    <th>Trading</th>
                    <th></th>
                  </tbody>
                  <tbody>
                    <%= for nts <- Keyword.values(@naive_trader_settings_paginate.list) do %>
                      <%= if @edit_row == nts.symbol do %>
                        <tr>
                          <td>
                            <input type="hidden" name="symbol" value="<%= nts.symbol %>">
                            <%= nts.symbol %>
                          </td>
                          <td>
                              <input class="form-control input-sm" type="text" name="budget" value="<%= nts.budget %>">
                          </td>
                          <td>
                            <input class="form-control input-sm" type="text" name="profit_interval" value="<%= nts.profit_interval %>">
                          </td>
                          <td>
                            <input class="form-control input-sm" type="text" name="buy_down_interval" value="<%= nts.buy_down_interval %>">
                          </td>
                          <td>
                            <input class="form-control input-sm" type="text" name="chunks" value="<%= nts.chunks %>">
                          </td>
                          <td>
                            <input class="form-control input-sm" type="text" name="stop_loss_interval" value="<%= nts.stop_loss_interval %>">
                          </td>
                          <td>
                            <select class="form-control input-sm" name="trading" data-enpassusermodified="yes">
                              <option value="true" <%= trading_select(nts.trading)[true] %>>Enabled</option>
                              <option value="false" <%= trading_select(nts.trading)[false] %>>Disabled</option>
                            </select>
                          </td>
                          <td><button type="submit" class="btn btn-block btn-info btn-xs"><span class="fa fa-edit"></span>Save</button></td>
                        </tr>
                      <% else %>
                        <tr>
                          <td><%= nts.symbol %></td>
                          <td><%= nts.budget %></td>
                          <td><%= nts.profit_interval %></td>
                          <td><%= nts.buy_down_interval %></td>
                          <td><%= nts.chunks %></td>
                          <td><%= nts.stop_loss_interval %></td>
                          <td><span class="label label-<%= trading_decoration()[nts.trading] %>"><%= trading_status()[nts.trading] %></span></td>
                          <td><button phx-click="edit-row-<%= nts.symbol %>" type="button" class="btn btn-block btn-primary btn-xs"><span class="fa fa-edit"></span> Edit</button></td>
                        </tr>
                      <%end %>
                    <% end %>
                  </tbody>
                </table>
              </form>
            </div>
            <div class="box-footer clearfix">
              <span><%= @naive_trader_settings_paginate.total %> rows</span>
              <ul class="pagination pagination-sm no-margin pull-right">
                <li><a phx-click="pagination-1" href="#">«</a></li>
                <%= for link <- @naive_trader_settings_paginate.links do %>
                  <li <%= if link == @naive_trader_settings_paginate.page do %>
                      class="active"
                    <% end %>
                  >
                    <a phx-click="pagination-<%= link %>" href="#"><%= link %></a>
                  </li>
                <% end %>
                <li><a phx-click="pagination-<%= @naive_trader_settings_paginate.pages %>" href="#">»</a></li>
              </ul>
            </div>
          <% end %>
          <!-- /.box-body -->
        </div>
        <!-- /.box -->
      </div>
    </div>
    """
  end

  def mount(%{}, socket) do
    {:ok, assign(socket, naive_trader_settings_paginate: pagination(10, 1), rows_numbers: [10, 20, 30, 40, 50], set_rows: 10, edit_row: nil)}
  end

  defp trading_status(), do: %{:true => "Trading", :false => "Disabled"}
  defp trading_decoration(), do: %{:true => "success", :false => "danger"}
  defp trading_select(:true), do: %{:true => "selected"}
  defp trading_select(:false), do: %{:false => "selected"}

  def handle_event("validate",  %{"search" => search}, socket) do
    result = Hefty.fetch_naive_trader_settings(search)
             |> Enum.into([], &{:"#{&1.symbol}", &1})
    {:noreply, assign(socket, naive_trader_settings_paginate: %{:list => result})}
  end

  def handle_event("rows", %{"rows_per_page" => limit} , socket) do
    {:noreply, assign(socket, naive_trader_settings_paginate:  pagination(String.to_integer(limit), 1), set_rows: String.to_integer(limit))}
  end

  def handle_event("pagination-" <> page, _, socket) do
    {:noreply, assign(socket, naive_trader_settings_paginate: pagination(socket.assigns.naive_trader_settings_paginate.limit, String.to_integer(page)))}
  end

  def handle_event("edit-row-" <> symbol, _, socket), do: {:noreply, assign(socket, edit_row: symbol)}

  def handle_event("save-row", data, socket) do
    Hefty.update_naive_trader_settings(data);
    {
      :noreply, assign(socket,
      naive_trader_settings_paginate: pagination(
        socket.assigns.naive_trader_settings_paginate.limit,
        socket.assigns.naive_trader_settings_paginate.page),
      edit_row: nil)
    }
  end

  defp pagination(limit, page) do
    pagination = Hefty.fetch_naive_trader_settings(((page - 1) * limit), limit)
                 |> Enum.into([], &{:"#{&1.symbol}", &1})

    all = Hefty.fetch_naive_trader_settings()

    links = Enum.filter((page-3)..(page+3), & &1 >= 1 and &1 <= round(Float.ceil(length(all) / limit)))

    %{
      :list => pagination,
      :total => length(all),
      :pages => round(Float.ceil(length(all) / limit)),
      :links => links,
      :page => page,
      :limit => limit
    }
  end
end
