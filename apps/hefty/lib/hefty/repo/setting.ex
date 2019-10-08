defmodule Hefty.Repo.Setting do
  @moduledoc false

  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}

  schema "settings" do
    field(:key, :string)
    field(:value, :string)

    timestamps()
  end
end
