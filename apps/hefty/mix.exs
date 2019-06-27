defmodule Hefty.MixProject do
  use Mix.Project

  def project do
    [
      app: :hefty,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :binance],
      mod: {Hefty.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:binance, "~> 0.6.0"}
      {:binance, git: "https://github.com/Cinderella-Man/binance.ex.git"},
      {:csv, "~> 2.3"},
      {:decimal, "~> 1.7"},
      {:ecto_sql, "~> 3.0"},
      {:flow, "~> 0.14"},
      {:json, "~> 1.3"},
      {:postgrex, ">= 0.0.0"},
      {:timex, "~> 3.5"},
      {:websockex, "~> 0.4.0"},
      {:ui, in_umbrella: true}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
