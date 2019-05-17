defmodule Hefty.Repo.StreamingSetting do
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "streaming_settings" do
    field(:symbol, :string)
    field(:platform, :string, default: "Binance")
    field(:enabled, :boolean, default: false)

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
