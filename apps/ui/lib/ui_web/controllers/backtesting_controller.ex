defmodule UiWeb.BacktestingController do
  @moduledoc false

  use UiWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Backtesting")
    |> assign(:section_subtitle, "Stream data through the system and check results")
    |> live_render(UiWeb.BacktestingLive, session: %{})
  end
end
