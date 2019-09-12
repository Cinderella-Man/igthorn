# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Ui2.Repo.insert!(%Ui2.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Hefty.Repo.Binance.{Balance, Pair}
alias Hefty.Repo.{StreamingSetting, NaiveTraderSetting, Setting}
import Ecto.Query
require Logger

binance_client = Application.get_env(:hefty, :exchanges).binance

defmodule Helpers do

  def create_balance({asset, precision}) do
    %Balance{
      asset: asset,
      precision: precision
    }
  end

  def create_pair(symbol, balances_map) do
    filters = symbol["filters"]

    {max_quantity, min_quantity, step_size} = filters
    |> fetch_lot_size_filter()

    {max_price, min_price, tick_size} = filters
    |> fetch_price_filter()

    %Pair{
      symbol: symbol["symbol"],
      status: symbol["status"],
      base_asset_id: balances_map[symbol["baseAsset"]].id,
      quote_asset_id: balances_map[symbol["quoteAsset"]].id,
      max_quantity: max_quantity,
      min_quantity: min_quantity,
      quantity_step_size: step_size,
      max_price: max_price,
      min_price: min_price,
      price_tick_size: tick_size
    }
  end

  defp fetch_lot_size_filter(filters) do
    res = filters
    |> Enum.find(nil, &(&1["filterType"] == "LOT_SIZE"))

    case res do
      %{
      "maxQty" => max_quantity,
      "minQty" => min_quantity,
      "stepSize" => step_size
      } -> { max_quantity, min_quantity, step_size }
      _ -> throw("Unable to retrieve lot size information")
    end
  end

  defp fetch_price_filter(filters) do
    res = filters
    |> Enum.find(nil, &(&1["filterType"] == "PRICE_FILTER"))

    case res do
      %{
        "maxPrice" => max_price,
        "minPrice" => min_price,
        "tickSize" => tick_size
      } -> { max_price, min_price, tick_size }
      _ -> throw("Unable to retrieve price information")
    end
  end

  def empty_balance(%{"free" => "0.00000000", "locked" => "0.00000000"}), do: true
  def empty_balance(_), do: false

  def update_balance(balances_map, %{"asset" => asset, "free" => free, "locked" => locked}) do
    balance = Ecto.Changeset.change(balances_map[asset], %{:free => free, :locked => locked})

    case Hefty.Repo.update(balance) do
      {:ok, struct} -> struct
      {:error, _changeset} -> throw("Unable to update " <> asset <> " balance")
    end
  end

  def create_naive_setting(%Pair{} = pair, balances_map) do
    default_settings = Keyword.fetch!(Application.get_all_env(:hefty), :trading).defaults

    %NaiveTraderSetting{
      :symbol => pair.symbol,
      :budget => balances_map[pair.quote_asset.asset].free,
      :profit_interval => default_settings.profit_interval,
      :buy_down_interval => default_settings.buy_down_interval,
      :chunks => default_settings.chunks,
      :stop_loss_interval => default_settings.stop_loss_interval,
      :retarget_interval => default_settings.retarget_interval,
      :rebuy_interval => default_settings.rebuy_interval,
      :status => "OFF"
    }
  end
end

Logger.info("Fetching exchange info to retrieve assets and symbols")

{:ok, %{symbols: symbols}} = binance_client.get_exchange_info()

Logger.info("Inserting 'empty' balances")

balances =
  symbols
  |> Enum.map(
    &[{&1["baseAsset"], &1["baseAssetPrecision"]}, {&1["quoteAsset"], &1["quotePrecision"]}]
  )
  |> List.flatten()
  |> Enum.uniq()
  |> Enum.map(&Helpers.create_balance/1)
  |> Enum.map(&(Hefty.Repo.insert(&1) |> elem(1)))

Logger.info("#{length(balances)} 'empty' balances inserted")

balances_map =
  balances
  |> Enum.into(%{}, fn b -> {b.asset, b} end)

Logger.info("Inserting #{length(symbols)} symbols(pairs)")

symbols
|> Enum.map(&Helpers.create_pair(&1, balances_map))
|> Enum.map(&(Hefty.Repo.insert(&1) |> elem(1)))

binance_config = Application.get_all_env(:binance)

if Keyword.fetch!(binance_config, :api_key) != "" do
  Logger.info("Loading current balances from Binance / updating db")

  {:ok, account} = binance_client.get_account()

  account.balances
  |> Enum.filter(&(!Helpers.empty_balance(&1)))
  |> Enum.map(&Helpers.update_balance(balances_map, &1))
end

Logger.info("Inserting default naive trader settings")

# Fetching pairs with quote assets joined
pairs =
  from(p in Pair, preload: [:quote_asset])
  |> Hefty.Repo.all()

# Fetching balances from db
balances = from(b in Balance) |> Hefty.Repo.all()

balances_map =
  balances
  |> Enum.into(%{}, fn b -> {b.asset, b} end)

pairs
|> Enum.map(&Helpers.create_naive_setting(&1, balances_map))
|> Enum.map(&(Hefty.Repo.insert(&1) |> elem(1)))

pairs
|> Enum.map(&%StreamingSetting{:symbol => &1.symbol})
|> Enum.map(&Hefty.Repo.insert/1)

Logger.info("Inserting app settings")

[%{:id => 1, :key => "api_key"}, %{:id => 2, :key => "secret_key"}]
|> Enum.map(&%Setting{:id => &1.id, :key => &1.key})
|> Enum.map(&Hefty.Repo.insert/1)

Logger.info("Seeding finished")
