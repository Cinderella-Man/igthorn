defmodule UiWeb.OrdersController do
  @moduledoc false

  use UiWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Orders")
    |> assign(:section_subtitle, "Orders")
    |> live_render(UiWeb.OrdersLive, session: %{})
  end
end
