defmodule UiWeb.PriceFeedLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
      <div class="row">
        <div class="col-xs-12">
          <div class="box">
            <div class="box-header">
              <h3 class="box-title">Current prices</h3>
            </div>
            <!-- /.box-header -->
            <div class="box-body">
              <div id="example2_wrapper" class="dataTables_wrapper form-inline dt-bootstrap"><div class="row"><div class="col-sm-6"></div><div class="col-sm-6"></div></div><div class="row"><div class="col-sm-12"><table id="example2" class="table table-bordered table-hover dataTable" role="grid" aria-describedby="example2_info">
                <thead>
                <tr role="row">
                  <th class="sorting_asc" tabindex="0" aria-controls="example2" rowspan="1" colspan="1" aria-sort="ascending" aria-label="Symbol">Symbol</th>
                  <th class="sorting" tabindex="0" aria-controls="example2" rowspan="1" colspan="1" aria-label="Last price">Price</th>
                </thead>
                <tbody>
                <%= for tick <- Keyword.values(@ticks) do %>
                  <tr role="row" class="odd">
                    <td class="sorting_1"><%= tick.symbol %></td>
                    <td><%= tick.price %></td>
                  </tr>
                <% end %>
                </tbody>
                <tfoot>
                <tr>
                <th rowspan="1" colspan="1">Symbol</th>
                <th rowspan="1" colspan="1">Price</th>
                </tr>
                </tfoot>
              </table>
              </div></div>
            </div>
            <!-- /.box-body -->
          </div>
          <!-- /.box -->
        </div>
        <!-- /.col -->
      </div>
    """
  end

  def mount(%{}, socket) do
    symbol_list = Hefty.fetch_streaming_symbols()

    ticks = symbol_list
      |> Enum.map(&(elem(&1, 0)))
      |> Enum.map(&(Hefty.fetch_tick(&1)))
      |> Enum.into([], &{:"#{&1.symbol}", &1})

    symbol_list
        |> Enum.map(&(elem(&1, 1)))
        |> Enum.map(&(Hefty.Streaming.Streamer.subscribe(&1)))

    {:ok, assign(socket, ticks: ticks)}
  end

  def handle_info({:trade_event, event}, socket) do
    ticks = Keyword.update!(
      socket.assigns.ticks,
      :"#{event.symbol}",
      &(%{&1 | :price => event.price})
    )

    {:noreply, assign(socket, ticks: ticks)}
  end
end
