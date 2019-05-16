defmodule Hefty.Repo do
  use Ecto.Repo,
    otp_app: :hefty,
    adapter: Ecto.Adapters.Postgres
end
