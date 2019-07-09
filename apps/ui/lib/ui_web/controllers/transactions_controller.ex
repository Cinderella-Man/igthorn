defmodule UiWeb.TransactionsController do
  use UiWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Transactions")
    |> assign(:section_subtitle, "Transactions")
    |> live_render(UiWeb.TransactionsLive, session: %{})
  end
end