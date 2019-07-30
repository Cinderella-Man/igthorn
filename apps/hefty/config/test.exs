# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# third-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :hefty, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:hefty, :key)
#
# You can also configure a third-party app:
#
#     config :logger, level: :info
#

config :hefty,
  exchanges: %{
    binance: Hefty.Exchanges.BinanceMock
  },
  trading: %{
    :defaults => %{
      :fee => "0.00075"
      # :fee => "0.001"
    }
  }

# Configure your database
config :hefty, Hefty.Repo, database: "hefty_test"

config :logger, level: :debug
