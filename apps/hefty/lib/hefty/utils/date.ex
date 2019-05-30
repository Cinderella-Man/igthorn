defmodule Hefty.Utils.Date do

  def ymdToTs(date) do
    date
    |> ymdToNaiveDate
    |> naiveDateToTs
  end

  def ymdToNaiveDate(date) do
    NaiveDateTime.from_iso8601!("#{date}T00:00:00.000Z")
  end  

  def naiveDateToTs(date) do
    date
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end
end
