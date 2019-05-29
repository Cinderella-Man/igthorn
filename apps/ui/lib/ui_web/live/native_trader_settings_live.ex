defmodule UiWeb.NativeTraderSettingsLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div class="row">
      <div class="col-xs-12">
        <div class="box">
          <div class="box-header">
            <h3 class="box-title">Native trader settings</h3>

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
          <%= if length(@native_trader_settings) > 0 do %>
            <div class="box-body table-responsive no-padding">
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
                  <%= for nts <- Keyword.values(@native_trader_settings) do %>
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
            <div class="box-body">
            <div id="example1_wrapper" class="dataTables_wrapper form-inline dt-bootstrap">
              <div class="row">
                <div class="col-sm-5">
                  <div class="dataTables_info" id="example2_info" role="status" aria-live="polite">
                    Showing 1 to 10 of 57 entries
                  </div>
                </div>
                <div class="col-sm-7">
                  <div class="dataTables_paginate paging_simple_numbers" id="example1_paginate">
                    <ul class="pagination">
                      <li class="paginate_button previous disabled" id="example2_previous">
                        <a href="#" aria-controls="example2" data-dt-idx="0" tabindex="0">Previous</a>
                      </li>
                      <li class="paginate_button active">
                        <a href="#" aria-controls="example2" data-dt-idx="1" tabindex="0">1</a>
                      </li>
                      <li class="paginate_button ">
                        <a href="#" aria-controls="example2" data-dt-idx="2" tabindex="0">2</a>
                      </li>
                      <li class="paginate_button ">
                        <a href="#" aria-controls="example2" data-dt-idx="3" tabindex="0">3</a>
                      </li>
                      <li class="paginate_button ">
                        <a href="#" aria-controls="example2" data-dt-idx="4" tabindex="0">4</a>
                      </li>
                      <li class="paginate_button ">
                        <a href="#" aria-controls="example2" data-dt-idx="5" tabindex="0">5</a>
                      </li>
                      <li class="paginate_button ">
                        <a href="#" aria-controls="example2" data-dt-idx="6" tabindex="0">6</a>
                      </li>
                      <li class="paginate_button next" id="example2_next">
                        <a href="#" aria-controls="example2" data-dt-idx="7" tabindex="0">Next</a>
                      </li>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{}, socket) do
    native_trader_settings = Hefty.fetch_native_trader_settings()
      |> Enum.into([], &{:"#{&1.symbol}", &1})
    IO.inspect(native_trader_settings)

    {:ok, assign(socket, native_trader_settings: native_trader_settings)}
  end

  defp trading_status(), do: %{:true => "Trading", :false => "Disabled"}
  defp trading_decoration(), do: %{:true => "success", :false => "danger"}

  def handle_event("validate", %{"native_trader_settings" => params}, socket) do
#    changeset =
#      %NaiveTraderSetting{}
#      |> Actions()
  end
end