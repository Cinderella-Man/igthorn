defmodule UiWeb.NaiveSettingsController do
  use UiWeb, :controller

  def index(conn, _params) do
    conn
      |> assign(:page_title, "Naive trader settings")
      |> assign(:section_subtitle, "Setting and enabling or disabling for naive trading")
      |> live_render(UiWeb.NaiveTraderSettingsLive, session: %{})
  end
end