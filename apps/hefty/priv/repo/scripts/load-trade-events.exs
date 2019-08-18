#! /usr/bin/env elixir
#
# A Template for writing an Elixir script by
# Andreas Altendorfer <andreas@altendorfer.at>
defmodule Shell do
  require Logger

  use Timex

  @db_database Keyword.fetch!(Application.get_env(:hefty, Hefty.Repo), :database)
  @db_hostname Keyword.fetch!(Application.get_env(:hefty, Hefty.Repo), :hostname)
  @db_username Keyword.fetch!(Application.get_env(:hefty, Hefty.Repo), :username) 
  @db_password Keyword.fetch!(Application.get_env(:hefty, Hefty.Repo), :password)

  @default_link "https://github.com/Cinderella-Man/binance-trade-events/raw/master/XRPUSDT/"

  #
  # Add your script here
  #
  @opts [
    strict: [
      symbol: :string,
      link: :string,
      path: :string,
      from: :string,
      to: :string
    ],
    aliases: [
      s: :symbol,
      l: :link,
      p: :path,
      f: :from,
      t: :to
    ]
  ]

  #
  # Call your script here
  #
  def run({ args, _ }) do

    symbol = Keyword.fetch!(args, :symbol)
    path = Keyword.fetch!(args, :path)
    from = Keyword.fetch!(args, :from)
    to = Keyword.fetch!(args, :to)

    if (!File.exists?(path)) do
      Logger.info("Unabled to find directory #{path} - creating a new directory")
      File.mkdir_p!(path)
    end

    from = Timex.parse!(from, "%F", :strftime)
    to = Timex.parse!(to, "%F", :strftime)

    if (Timex.compare(from, to) == 1) do
      Logger.info("`From date` greather than `to date`")
      raise "Invalid from/to dates"
    end

    link = case Keyword.fetch(args, :link) do
      {:ok, val} -> val
      :error     -> @default_link
    end

    :inets.start()
    :ssl.start()

    expected_files = generate_expected_files(symbol, from, to)

    expected_files
    |> Enum.filter(&(existing_file(&1, path)))
    |> Enum.map(&(fetch_file(&1, link, path)))

    total_imported = expected_files
    |> Enum.map(&(load_to_db(&1, path)))
    |> Enum.sum()

    "Finished successfully. Inserted #{total_imported}"
  end

  defp generate_expected_files(symbol, from, to) do
    files = generate_expected_files([], symbol, from, to)
    Logger.info("Expecting below filenames to be downloaded:\n#{Enum.join(files, "\n")}")
    files
  end

  defp existing_file(file_name, path) do
    full_path = Path.join([path, "#{file_name}.csv"])
    case File.exists?(full_path) do
      true -> Logger.info("Skipping #{full_path} as it already exist")
              false
      false -> true
    end
  end

  defp generate_expected_files(files, symbol, from, to) do
    case Timex.compare(from, to) do
      0 -> [generate_file_name(symbol, from) | files] |> Enum.reverse()
      -1 -> generate_expected_files(
        [generate_file_name(symbol, from) | files],
        symbol,
        Timex.shift(from, days: 1),
        to
      )
    end
  end

  defp generate_file_name(symbol, date) do
    {:ok, ymd} = Timex.format(date, "{YYYY}-{0M}-{0D}")
    "#{symbol}-#{ymd}"
  end

  defp fetch_file(file_name, link, path) do

    url = "#{link}#{file_name}.csv.gz"
    
    Logger.info("Downloading #{url}")

    {:ok, {_status, _headers, contents}} = :httpc.request(
      :get,
      {url |> String.to_charlist(), []},
      [],
      []
    )

    csv_file_path = Path.join(path, "#{file_name}.csv")
    |> String.to_charlist()

    File.write(csv_file_path, :zlib.gunzip(contents))

    csv_file_path = csv_file_path |> List.to_string()

    Logger.info("Download successful. CSV save to #{csv_file_path}")

    csv_file_path
  end

  defp load_to_db(file_name, path) do
    full_path = Path.join([path, "#{file_name}.csv"])
    Logger.info("Inserting records from #{file_name} to #{@db_database} db")

    command = "PGPASSWORD=#{@db_password} psql -U#{@db_username} -h #{@db_hostname} -d#{@db_database}  -c \"\\COPY trade_events FROM '#{full_path}' WITH (FORMAT csv, delimiter ';');\""
    :os.cmd(command |> String.to_charlist())
    |> decode_result
  end

  defp decode_result(result) do
    chunks = result
    |> List.to_string()
    |> String.slice(0..-2)
    |> String.split(" ")

    case chunks do
      ["COPY", num] -> {n, _} = Integer.parse(num)
                       n
      _ -> Logger.error(result)
           0
    end
  end

  def main(args) do
    OptionParser.parse!(args, @opts)
    |> run
  end
end

#
# MAIN
#
System.argv()
|> Shell.main()
|> IO.puts()
