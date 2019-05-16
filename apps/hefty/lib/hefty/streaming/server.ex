defmodule Hefty.Streaming.Server do
  use GenServer

  import Ecto.Query, only: [from: 1]
  import Ecto.Changeset, only: [cast: 3]

  defmodule State do
    defstruct workers: %{}
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_args) do
    GenServer.cast(__MODULE__, :init_streams)
    {:ok, %State{}}
  end

  def flip_stream(symbol) do
    GenServer.cast(__MODULE__, {:flip, symbol})
  end

  def handle_cast(:init_streams, _state) do
    workers = (from nts in Hefty.Repo.Binance.NaiveTraderSetting)
      |> Hefty.Repo.all
      |> Enum.filter(&(&1.streaming))
      |> Enum.map(&{&1.symbol, start_streaming(&1.symbol)})
      |> Enum.into(%{})

    {:noreply, %State{:workers => workers}}
  end

  def handle_cast({:flip, symbol}, state) do
    flip_db_flag(symbol)

    case Map.get(state.workers, symbol, false) do
      false -> child_pid = start_streaming(symbol)
              workers = Map.put(state.workers, symbol, child_pid)
               {:noreply, %{state | :workers => workers}}
      child_pid -> stop_child(child_pid)
              workers = Map.delete(state.workers, symbol)
              {:noreply, %{state | :workers => workers}}
    end
  end

  defp flip_db_flag(symbol) do
    settings = Hefty.Repo.Binance.NaiveTraderSetting.fetch_settings(symbol)
    settings
      |> cast(%{:streaming => !settings.streaming}, [:streaming])
      |> Hefty.Repo.update!
  end

  defp start_streaming(symbol) do
    {:ok, pid} = DynamicSupervisor.start_child(
      Hefty.Streaming.DynamicStreamerSupervisor,
      {Hefty.Streaming.Streamer, symbol}
    )
    pid
  end

  defp stop_child(child_pid) do
    :ok = DynamicSupervisor.terminate_child(
      Hefty.Streaming.DynamicStreamerSupervisor,
      child_pid
    )
  end
end
