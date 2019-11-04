defmodule UiWeb.NaiveSettingsController do
  @moduledoc false

  use UiWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Naive trader settings")
    |> assign(:section_subtitle, "Settings and enabling or disabling for naive trading")
    |> live_render(UiWeb.NaiveTraderSettingsLive, session: %{})
  end
end
