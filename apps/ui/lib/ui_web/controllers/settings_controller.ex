defmodule UiWeb.SettingsController do
  @moduledoc false

  use UiWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Settings")
    |> assign(:section_subtitle, "Settings")
    |> live_render(UiWeb.SettingsLive, session: %{})
  end
end
