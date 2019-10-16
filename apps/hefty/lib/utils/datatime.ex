defmodule Hefty.Utils.Datetime do
  use Timex

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

  def get_timestamps(start_date, end_date) do
    from_datetime = NaiveDateTime.from_iso8601!("#{start_date}T00:00:00.000Z")

    to_datetime =
      NaiveDateTime.from_iso8601!("#{end_date}T00:00:00.000Z")
      |> NaiveDateTime.add(24 * 60 * 60, :second)

    from_timestamp =
      from_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    to_timestamp =
      to_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    [from_timestamp * 1000, to_timestamp * 1000]
  end

  def get_timestamps_by(interval) do
    date = Timex.today()

    seconds_map = %{
      :today => get_timestamps(date),
      :yesterday => get_timestamps(Timex.shift(date, days: -1)),
      :this_week => get_timestamps(Timex.beginning_of_week(date), Timex.end_of_week(date)),
      :last_week =>
        get_timestamps(
          Timex.beginning_of_week(Timex.shift(date, weeks: -1)),
          Timex.end_of_week(Timex.shift(date, weeks: -1))
        ),
      :this_month => get_timestamps(Timex.beginning_of_month(date), Timex.end_of_month(date)),
      :last_month =>
        get_timestamps(
          Timex.beginning_of_month(Timex.shift(date, months: -1)),
          Timex.end_of_month(Timex.shift(date, months: -1))
        ),
      :this_year => get_timestamps(Timex.beginning_of_year(date), Timex.end_of_year(date)),
      :last_year =>
        get_timestamps(
          Timex.beginning_of_year(Timex.shift(date, years: -1)),
          Timex.end_of_year(Timex.shift(date, years: -1))
        )
    }

    seconds_map[interval]
  end

  def get_last(n, interval, datetime) do
    seconds_map = %{:day => 86_400, :week => 604_800, :year => 31_536_000}

    to_datetime = NaiveDateTime.from_iso8601!("#{datetime}")

    to_timestamp =
      to_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    seconds = seconds_map[interval] * n * -1
    from_datetime = NaiveDateTime.add(to_datetime, seconds, :second)

    from_timestamp =
      from_datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    [from_timestamp * 1000, to_timestamp * 1000]
  end

  def get_last_days(n) do
    day = Date.utc_today() |> Date.add(-n + 1)

    Interval.new(from: day, until: [days: n], right_open: true)
    |> Interval.with_step(days: 1)
    |> Enum.map(&Timex.format!(&1, "%Y-%m-%d", :strftime))
  end
end
