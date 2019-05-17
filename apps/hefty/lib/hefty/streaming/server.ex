defmodule Hefty.Streaming.Server do
  use GenServer

  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset, only: [cast: 3]

  defmodule State do
    defstruct workers: %{}
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    GenServer.cast(__MODULE__, :init_streams)
    {:ok, %State{}}
  end

  def flip_stream(symbol) do
    GenServer.cast(__MODULE__, {:flip, symbol})
  end

  def fetch_streaming_symbols() do
    GenServer.call(__MODULE__, :fetch_streamers)
  end

  def handle_call(:fetch_streamers, _from, state) do
    {:reply, state.workers, state}
  end

  def handle_cast(:init_streams, _state) do
    workers =
      from(nts in Hefty.Repo.StreamingSetting, where: nts.platform == "Binance" and nts.enabled == true)
      |> Hefty.Repo.all()
      |> Enum.map(&{&1.symbol, start_streaming(&1.symbol)})
      |> Enum.into(%{})

    {:noreply, %State{:workers => workers}}
  end

  def handle_cast({:flip, symbol}, state) do
    flip_db_flag(symbol)

    case Map.get(state.workers, symbol, false) do
      false ->
        child_pid = start_streaming(symbol)
        workers = Map.put(state.workers, symbol, child_pid)
        {:noreply, %{state | :workers => workers}}

      child_pid ->
        stop_child(child_pid)
        workers = Map.delete(state.workers, symbol)
        {:noreply, %{state | :workers => workers}}
    end
  end

  defp flip_db_flag(symbol) do
    settings = from(nts in Hefty.Repo.StreamingSetting, where: nts.symbol == ^symbol)
      |> Hefty.Repo.one()

    settings
    |> cast(%{:enabled => !settings.enabled}, [:enabled])
    |> Hefty.Repo.update!()
  end

  defp start_streaming(symbol) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        Hefty.Streaming.DynamicStreamerSupervisor,
        {Hefty.Streaming.Streamer, symbol}
      )

    Process.monitor(pid)

    pid
  end

  defp stop_child(child_pid) do
    :ok =
      DynamicSupervisor.terminate_child(
        Hefty.Streaming.DynamicStreamerSupervisor,
        child_pid
      )
  end

  def handle_info({:DOWN, _ref, pid, :process, _reason}, state) do
    {symbol, _} = state.workers
      |> Enum.find(false, fn({_, process_pid}) -> process_pid == pid end)

    new_pid = start_streaming(symbol)

    workers = %{state.workers | :symbol => new_pid}

    {:noreply, %{state | :workers => workers }}
  end
end
