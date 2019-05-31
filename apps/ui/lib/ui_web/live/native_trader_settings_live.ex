defmodule UiWeb.NativeTraderSettingsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div class="row">
      <div class="col-xs-12">
        <div class="box">
          <div class="box-header">
            <h3 class="box-title">Current prices</h3>

            <div class="box-tools">
              <form phx_change="validate" phx-submit="validate">
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
          <%= if length(@native_trader_settings_paginate.list) > 0 do %>
            <div class="box-body table-responsive no-padding">

              <div class="box-body">
                <form phx_change="rows" phx-submit="rows">
                  <div class="input-group input-group-sm col-xs-1">
                    <select class="form-control" name="rows_per_page">
                      <option value="10" selected>10</option>
                      <option value="20">20</option>
                      <option value="30">30</option>
                      <option value="40">40</option>
                      <option value="50">50</option>
                    </select>
                    <span class="input-group-btn">
                      <button type="submit" class="btn btn-info btn-flat">Rows</button>
                    </span>
                  </div>
                </form>
              </div>

              <br>

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
                  <%= for nts <- Keyword.values(@native_trader_settings_paginate.list) do %>
                    <tr>
                      <td><%= nts.symbol %></td>
                      <td><%= nts.budget %></td>
                      <td><%= nts.profit_interval %></td>
                      <td><%= nts.buy_down_interval %></td>
                      <td><%= nts.chunks %></td>
                      <td><%= nts.stop_loss_interval %></td>
                      <td><span class="label label-<%= trading_decoration()[nts.trading] %>"><%= trading_status()[nts.trading] %></span></td>
                      <td><button type="button" class="btn btn-block btn-primary btn-xs"><span class="fa fa-edit"></span> Edit</button></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
            <div class="box-footer clearfix">
              <span>Test info</span>
              <ul class="pagination pagination-sm no-margin pull-right">
                <li><a phx-click="pagination-1" href="#">«</a></li>
                <%= for link <- @native_trader_settings_paginate.links do %>
                  <li <%= if link == @native_trader_settings_paginate.page do %>
                      class="active"
                    <% end %>
                  >
                    <a phx-click="pagination-<%= link %>" href="#"><%= link %></a>
                  </li>
                <% end %>
                <li><a phx-click="pagination-<%= @native_trader_settings_paginate.pages %>" href="#">»</a></li>
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
    {:ok, assign(socket, native_trader_settings_paginate: pagination(10, 1))}
  end

  defp trading_status(), do: %{:true => "Trading", :false => "Disabled"}
  defp trading_decoration(), do: %{:true => "success", :false => "danger"}

  def handle_event("validate", %{"native_trader_settings" => params}, socket) do
    IO.inspect('czesc')
#    changeset =
#      %NaiveTraderSetting{}
#      |> Actions()
  end

  def handle_event("rows", %{"rows_per_page" => limit} , socket) do
    {:noreply, assign(socket, native_trader_settings_paginate:  pagination(String.to_integer(limit), 1))}
  end

  def handle_event("pagination-" <> page, _, socket) do
    {:noreply, assign(socket, native_trader_settings_paginate: pagination(socket.assigns.native_trader_settings_paginate.limit, String.to_integer(page)))}
  end

  defp pagination(limit, page) do
    pagination = Hefty.fetch_native_trader_settings(((page - 1) * limit), limit)
       |> Enum.into([], &{:"#{&1.symbol}", &1})

    all = Hefty.fetch_native_trader_settings()

    links = Enum.filter((page-3)..(page+3), & &1 >= 1 and &1 <= round(Float.ceil(length(all) / limit)))

    IO.inspect(%{
      :total => length(all),
      :pages => round(Float.ceil(length(all) / limit)),
      :links => links,
      :page => page,
      :limit => limit
    })

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