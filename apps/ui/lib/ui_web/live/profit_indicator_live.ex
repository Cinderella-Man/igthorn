defmodule UiWeb.ProfitIndicatorLive do
  use Phoenix.LiveView

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
            <%= for elem <- row do %>
              <div class="col-md-<%= div(12, length(row)) %>">
                <div class="info-box">
                  <div class="info-box-content">
                    <span class="info-box-text"><%= elem.type %></span>
                    <span class="info-box-number"><%= elem.total || 0.0 %></span>
                  </div>
                  <!-- /.info-box-content -->
                </div>
                <!-- /.info-box -->
              </div>
            <% end %>
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
      [
        %{
          :symbol => symbol,
          :type => "today",
          :total => get_profit_base_currency(:today, symbol)
        },
        %{
          :symbol => symbol,
          :type => "yesterday",
          :total => get_profit_base_currency(:yesterday, symbol)
        }
      ],
      [
        %{
          :symbol => symbol,
          :type => "this week",
          :total => get_profit_base_currency(:this_week, symbol)
        },
        %{
          :symbol => symbol,
          :type => "last week",
          :total => get_profit_base_currency(:last_week, symbol)
        }
      ],
      [
        %{
          :symbol => symbol,
          :type => "this month",
          :total => get_profit_base_currency(:this_month, symbol)
        },
        %{
          :symbol => symbol,
          :type => "last month",
          :total => get_profit_base_currency(:last_month, symbol)
        }
      ],
      [
        %{
          :symbol => symbol,
          :type => :this_year,
          :total => get_profit_base_currency(:this_year, symbol)
        },
        %{
          :symbol => symbol,
          :type => :last_year,
          :total => get_profit_base_currency(:last_year, symbol)
        }
      ],
      [
        %{
          :symbol => symbol,
          :type => :all,
          :total => get_profit_base_currency(:all, symbol)
        }
      ]
    ]
  end

  defp get_profit_base_currency(:all, symbol) do
    Hefty.Trades.profit_base_currency_by_time(symbol)
  end

  defp get_profit_base_currency(interval, symbol) do
    [from, to] = Hefty.Utils.Datetime.get_timestamps_by(interval)
    Hefty.Trades.profit_base_currency_by_time(from, to, symbol)
  end
end
