defmodule UiWeb.NativeSettingsController do
  use UiWeb, :controller

  def index(conn, _params) do
    conn
      |> assign(:page_title, "Native trader settings")
      |> assign(:section_subtitle, "To Do")
      |> live_render(UiWeb.NativeTraderSettingsLive, session: %{})
  end
end