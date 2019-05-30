defmodule UiWeb.StreamingSettingsController do
  use UiWeb, :controller

  def index(conn, _params) do
    settings =
      Hefty.fetch_stream_settings()
      |> Enum.into([], &{:"#{&1.symbol}", &1})

    conn
    |> assign(:page_title, "Streaming settings")
    |> assign(:section_subtitle, "Enabled or disable streaming on specific symbols")
    |> live_render(UiWeb.SettingsLive, session: %{settings: settings})
  end
end
