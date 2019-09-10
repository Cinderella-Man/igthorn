defmodule Hefty.Utils.Datetime do
  def get_timestamps(date) do
    from_datetime = NaiveDateTime.from_iso8601!("#{date}T00:00:00.000Z")

    from_timestamp =
      from_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    to_datetime = NaiveDateTime.add(from_datetime, 24 * 60 * 60, :second)

    to_timestamp =
      to_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    [from_timestamp * 1000, to_timestamp * 1000]
  end

  def get_last(n, interval, datetime) do
    times = %{:day => 86400, :week => 604_800, :year => 31_536_000}

    to_datetime = NaiveDateTime.from_iso8601!("#{datetime}")

    to_timestamp =
      to_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    time = times[interval] * n * -1
    from_datetime = NaiveDateTime.add(to_datetime, time, :second)

    from_timestamp =
      from_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    [from_timestamp * 1000, to_timestamp * 1000]
  end
end
