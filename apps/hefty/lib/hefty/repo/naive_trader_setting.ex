defmodule Hefty.Repo.NaiveTraderSetting do
  @moduledoc false

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "naive_trader_settings" do
    field(:symbol, :string)
    field(:budget, :string)
    field(:retarget_interval, :string)
    field(:profit_interval, :string)
    field(:buy_down_interval, :string)
    field(:chunks, :integer)
    field(:stop_loss_interval, :string)
    field(:rebuy_interval, :string)
    field(:platform, :string, default: "Binance")
    field(:status, :string, default: "OFF")

    timestamps()
  end
end
