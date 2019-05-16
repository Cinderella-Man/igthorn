defmodule UiWeb.PageController do
  use UiWeb, :controller
  alias Phoenix.LiveView

  def index(conn, _params) do
    {:ok, account} = Binance.get_account()
    account = %{account |
      balances: account.balances |> Enum.filter(fn(balance) -> balance["free"] !== "0.00000000" or balance["locked"] !== "0.00000000" end)
    }

    LiveView.Controller.live_render(conn, UiWeb.DashboardLive, session: %{account: account})
  end
end
