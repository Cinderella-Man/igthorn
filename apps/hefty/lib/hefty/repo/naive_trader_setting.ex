defmodule Hefty.Repo.NaiveTraderSetting do
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "naive_trader_settings" do
    field(:symbol, :string)
    field(:budget, :string)
    field(:profit_interval, :string)
    field(:buy_down_interval, :string)
    field(:chunks, :integer)
    field(:stop_loss_interval, :string)
    field(:platform, :string, default: "Binance")
    field(:trading, :boolean, default: false)

    timestamps()
  end

  def fetch_settings(symbol) do
    query =
      from(s in __MODULE__,
        where: s.symbol == ^symbol
      )

    Hefty.Repo.one(query)
  end
end
