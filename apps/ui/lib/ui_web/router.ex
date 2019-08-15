defmodule UiWeb.Router do
  use UiWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(Phoenix.LiveView.Flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", UiWeb do
    pipe_through(:browser)

    get("/", PageController, :index)
    get("/streaming-settings", StreamingSettingsController, :index)
    get("/orders", OrdersController, :index)
    get("/trades", TradesController, :index)
    get("/transactions", TransactionsController, :index)
    get("/backtesting", BacktestingController, :index)
    get("/naive-trader-settings", NaiveSettingsController, :index)
  end

  # Other scopes may use custom stacks.
  # scope "/api", UiWeb do
  #   pipe_through :api
  # end
end
