defmodule Hefty.Traders do
  import Ecto.Query, only: [from: 2]
  require Logger

  def fetch_naive_trader_settings() do
    from(nts in Hefty.Repo.NaiveTraderSetting,
      order_by: nts.symbol
    )
    |> Hefty.Repo.all()
  end

  def fetch_naive_trader_settings(offset, limit, symbol \\ "") do
    Logger.debug("Fetching naive trader settings for a symbol(#{symbol})")

    from(nts in Hefty.Repo.NaiveTraderSetting,
      order_by: nts.symbol,
      where: like(nts.symbol, ^"%#{String.upcase(symbol)}%"),
      limit: ^limit,
      offset: ^offset
    )
    |> Hefty.Repo.all()
  end

  @spec count_naive_trader_settings(String.t()) :: number()
  def count_naive_trader_settings(symbol \\ "") do
    Logger.debug("Fetching number of naive trader settings for a symbol(#{symbol})")

    from(nts in Hefty.Repo.NaiveTraderSetting,
      select: count("*"),
      where: like(nts.symbol, ^"%#{String.upcase(symbol)}%")
    )
    |> Hefty.Repo.one()
  end

  def update_naive_trader_settings(data) do
    record = Hefty.Repo.get_by!(Hefty.Repo.NaiveTraderSetting, symbol: data["symbol"])

    nts =
      Ecto.Changeset.change(
        record,
        %{
          :budget => data["budget"],
          :buy_down_interval => data["buy_down_interval"],
          :chunks => String.to_integer(data["chunks"]),
          :profit_interval => data["profit_interval"],
          :rebuy_interval => data["rebuy_interval"],
          :retarget_interval => data["retarget_interval"],
          :stop_loss_interval => data["stop_loss_interval"],
          :trading => String.to_existing_atom(data["trading"])
        }
      )

    case Hefty.Repo.update(nts) do
      {:ok, struct} ->
        struct

      {:error, _changeset} ->
        throw("Unable to update " <> data["symbol"] <> " naive trader settings")
    end
  end

  @spec flip_trading(String.t()) :: :ok
  def flip_trading(symbol) when is_binary(symbol) do
    Logger.info("Flip trading for a symbol #{symbol}")
    Hefty.Algos.Naive.flip_trading(symbol)
  end

  @spec turn_off_trading(String.t()) :: :ok
  def turn_off_trading(symbol) when is_binary(symbol) do
    Logger.info("Turn off trading for a symbol #{symbol}")
    Hefty.Algos.Naive.turn_off(symbol)
  end

  @spec turn_on_trading(String.t()) :: :ok
  def turn_on_trading(symbol) when is_binary(symbol) do
    Logger.info("Turn on trading for a symbol #{symbol}")
    Hefty.Algos.Naive.turn_on(symbol)
  end
end
