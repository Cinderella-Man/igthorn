defmodule UiWeb.LayoutView do
  use UiWeb, :view

  def get_page_title(conn) do
    conn
      |> fetch_from_conn(
        :page_title,
        "Igthorn",
        " - Igthorn"
      )
  end

  def get_section_head(conn) do
    conn
      |> fetch_from_conn(
        :page_title,
        "Error"
      )
  end

  def get_section_subtitle(conn) do
    conn
      |> fetch_from_conn(
        :section_subtitle,
        "Error"
      )
  end

  defp fetch_from_conn(conn, key, default, suffix \\ "") do
    if conn.assigns[key] do
      "#{conn.assigns[key]}" <> suffix
    else
      default
    end
  end
end
