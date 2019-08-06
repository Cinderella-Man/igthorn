defmodule UiWeb.TradesController do
  use UiWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Trades")
    |> assign(:section_subtitle, "Trades")
    |> live_render(UiWeb.TradesLive, session: %{})
  end
end
