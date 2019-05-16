defmodule UiWeb.SettingsController do
  use UiWeb, :controller
  alias Phoenix.LiveView

  def index(conn, _params) do
    settings = Hefty.fetch_settings()
      |> Enum.into([], &{:"#{&1.symbol}", &1})
    LiveView.Controller.live_render(conn, UiWeb.SettingsLive, session: %{settings: settings})
  end
end
