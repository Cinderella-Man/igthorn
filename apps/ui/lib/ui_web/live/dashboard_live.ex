defmodule UiWeb.DashboardLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div class="">
      <div>
        <table>
          <tr>
            <th>Balances</th>
            <th>Open Orders</th>
            <th>Transactions</th>
          </tr>
          <tr>
            <td>
              <table>
                <tr>
                  <th>Assets</th>
                  <th>Available</th>
                  <th>Locked</th>
                </tr>
                <%= for balance <- @account.balances do %>
                  <tr>
                    <td><%= balance["asset"] %></td>
                    <td><%= balance["free"] %></td>
                    <td><%= balance["locked"] %></td>
                  </tr>
                <% end %>
              </table>
            </td>
            <td>
              <table>
                <tr>
                  <th>Symbol</th>
                  <th>Quantity</th>
                  <th>Price</th>
                </tr>
                <%= for balance <- @account.balances do %>
                  <tr>
                    <td><%= balance["asset"] %></td>
                    <td><%= balance["free"] %></td>
                    <td><%= balance["locked"] %></td>
                  </tr>
                <% end %>
              </table>
            </td>
            <td>
              <table>
                <tr>
                  <th>Symbol</th>
                  <th>Quantity</th>
                  <th>Price</th>
                </tr>
                <%= for balance <- @account.balances do %>
                  <tr>
                    <td><%= balance["asset"] %></td>
                    <td><%= balance["free"] %></td>
                    <td><%= balance["locked"] %></td>
                  </tr>
                <% end %>
              </table>
            </td>
          </tr>
        </table>

        <table>
          <tr>
            <th>Maker commission</th>
            <th>Taker commission</th>
          </tr>
          <tr>
            <td><%= @account.maker_commission %></td>
            <td><%= @account.taker_commission %></td>
          </tr>
        </table>

      </div>
    </div>
    """
  end

  def mount(%{account: account}, socket) do
    {:ok, assign(socket, account: account)}
  end
end
