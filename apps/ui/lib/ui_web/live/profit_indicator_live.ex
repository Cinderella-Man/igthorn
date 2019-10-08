defmodule UiWeb.ProfitIndicatorLive do
  use Phoenix.LiveView
  alias Timex, as: T

  def render(assigns) do
    ~L"""
    <div class="box box-default">
      <div class="box-header with-border">
        <h3 class="box-title">Total Profit</h3>

        <div class="box-tools pull-right">
          <button type="button" class="btn btn-box-tool" data-widget="collapse"><i class="fa fa-minus"></i>
          </button>
          <button type="button" class="btn btn-box-tool" data-widget="remove"><i class="fa fa-times"></i></button>
        </div>
      </div>
      <!-- /.box-header -->
      <div class="box-body">
        <div class="row">
          <%= if length(@symbols) > 0 do %>
            <div class="col-xs-3">
              <form phx-change="change-symbol" id="change-symbol">
                <select name="selected_symbol" class="form-control">
                  <%= for row <- @symbols do %>
                    <option value="<%= row %>"
                    <%= if row == @symbol do %>
                      selected
                    <% end %>
                    ><%= row %></option>
                  <% end %>
                </select>
              </form>
            </div>
          <% end %>
        </div><br>
        <div class="row">
          <%= for row <- @data do %>
            <div class="col-md-12">
              <div class="info-box">
                <div class="info-box-content">
                  <span class="info-box-text"><%= row.type %></span>
                  <span class="info-box-number"><%= row.total || 0.0 %></span>
                </div>
                <!-- /.info-box-content -->
              </div>
              <!-- /.info-box -->
            </div>
          <% end %>
        </div>
        <!-- /.row -->
      </div>
      <!-- /.box-body -->
    </div>
    """
  end

  def mount(%{}, socket) do
    symbols = ["ALL" | Hefty.Trades.get_all_trading_symbols()]

    {:ok, assign(socket, data: get_data(), symbol: "ALL", symbols: symbols)}
  end

  def handle_event("change-symbol", %{"selected_symbol" => "ALL"}, socket) do
    {:noreply,
     assign(socket,
       symbol: "ALL",
       symbols: socket.assigns.symbols,
       data: get_data()
     )}
  end

  def handle_event("change-symbol", %{"selected_symbol" => selected_symbol}, socket) do
    {:noreply,
     assign(socket,
       symbol: selected_symbol,
       symbols: socket.assigns.symbols,
       data: get_data(selected_symbol)
     )}
  end

  def get_data(symbol \\ '') do
    [
      %{
        :symbol => symbol,
        :type => :day,
        :total => get_profit_base_currency(1, :day, symbol)
      },
      %{
        :symbol => symbol,
        :type => :week,
        :total => get_profit_base_currency(1, :week, symbol)
      },
      %{
        :symbol => symbol,
        :type => :year,
        :total => get_profit_base_currency(1, :year, symbol)
      },
      %{
        :symbol => symbol,
        :type => :all,
        :total => get_profit_base_currency(1, :all, symbol)
      }
    ]
  end

  defp get_profit_base_currency(_n, :all, symbol) do
    Hefty.Trades.profit_base_currency_by_time(symbol)
  end

  defp get_profit_base_currency(n, interval, symbol) do
    [from, to] = Hefty.Utils.Datetime.get_last(n, interval, T.now())
    Hefty.Trades.profit_base_currency_by_time(from, to, symbol)
  end
end
