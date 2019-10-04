defmodule Igthorn.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "1.0.1",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Docs
      name: "Igthorn",
      source_url: "https://github.com/HedonSoftware/Igthorn",
      homepage_url: "http://igthorn.com/",
      docs: [
        # The main page in the docs
        main: "Hefty",
        logo: "docs/logo.png",
        extras: ["README.md"]
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:dialyxir, "~> 0.5", runtime: false}
    ]
  end
end
