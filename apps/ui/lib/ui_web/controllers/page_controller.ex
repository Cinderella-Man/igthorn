defmodule UiWeb.PageController do
  @moduledoc false

  use UiWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Dashboard")
    |> assign(:section_subtitle, "Overview of the system")
    |> live_render(UiWeb.DashboardLive, session: %{})
  end
end
