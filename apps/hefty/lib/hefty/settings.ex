defmodule Hefty.Settings do
  require Logger

  import Ecto.Query, only: [from: 2]
  alias Hefty.Repo.Setting

  @secret "EC7+ItmG04KZzcS1Bg3o1g==" # TODO - make this generate per app and keep in config

  def fetch_binance_api_details() do
    Logger.debug("Fetching binance api details")

    from(s in Setting,
        select: [s.key, s.value],
        where: s.key in ^["api_key", "secret_key"]
      )
      |> Hefty.Repo.all()
      |> Enum.map(&{String.to_atom(List.first(&1)), List.last(&1)})
      |> Map.new()
  end

  def update_binance_api_details(api_key, "secret_key_hash") do
    update_settings("api_key", api_key)
  end

  def update_binance_api_details(api_key, secret_key) do
    value = Hefty.Utils.Encrypt.encrypt(secret_key, @secret)
    update_settings("api_key", api_key)
    update_settings("secret_key", value)
  end

  defp update_settings(key, value) do
    setting = Hefty.Repo.get_by!(Setting, key: key)
    data =
      Ecto.Changeset.change(
        setting,
        %{:value => value}
      )

    case Hefty.Repo.update(data) do
      {:ok, struct} -> struct
      {:error, _changeset} -> throw("Unable to update setting key #{key}")
    end
  end
end
