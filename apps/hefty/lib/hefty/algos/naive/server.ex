defmodule Hefty.Algos.Naive.Server do
  use GenServer
  require Logger

  @doc """
  This is server that tracks which symbols are traded
  """

  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset, only: [cast: 3]

  defmodule State do
    defstruct symbol_supervisors: %{}
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    GenServer.cast(__MODULE__, :init_symbol_supervisors)
    {:ok, %State{}}
  end

  def flip_trading(symbol) do
    GenServer.cast(__MODULE__, {:flip, symbol})
  end

  def turn_off(symbol) do
    GenServer.cast(__MODULE__, {:turn_off, symbol})
  end

  def turn_on(symbol) do
    GenServer.cast(__MODULE__, {:turn_on, symbol})
  end

  def fetch_trading_symbols() do
    GenServer.call(__MODULE__, :fetch_trading_symbols)
  end

  def handle_call(:fetch_trading_symbols, _from, state) do
    {:reply, state.symbol_supervisors, state}
  end

  def handle_cast(:init_symbol_supervisors, _state) do
    symbol_supervisors =
      from(nts in Hefty.Repo.NaiveTraderSetting,
        where: nts.platform == "Binance" and nts.trading == true
      )
      |> Hefty.Repo.all()
      |> Enum.map(&{&1.symbol, start_symbol_supervisor(&1.symbol)})
      |> Enum.into(%{})

    {:noreply, %State{:symbol_supervisors => symbol_supervisors}}
  end

  def handle_cast({:flip, symbol}, state) do
    flip_db_flag(symbol)

    case Map.get(state.symbol_supervisors, symbol, false) do
      false ->
        Logger.info("Starting new supervision tree to trade on symbol", symbol: symbol)
        result = start_symbol_supervisor(symbol)
        symbol_supervisors = Map.put(state.symbol_supervisors, symbol, result)
        {:noreply, %{state | :symbol_supervisors => symbol_supervisors}}

      result ->
        stop_trading(symbol, result, state)
    end
  end

  def handle_cast({:turn_off, symbol}, state) do
    case Map.get(state.symbol_supervisors, symbol, false) do
      false ->
        {:noreply, state}

      result ->
        flip_db_flag(symbol)
        stop_trading(symbol, result, state)
    end
  end

  defp stop_trading(symbol, ref, state) do
    Logger.info("Stopping supervision tree to cancel trading on symbol", symbol: symbol)
    stop_child(ref)
    symbol_supervisors = Map.delete(state.symbol_supervisors, symbol)
    {:noreply, %{state | :symbol_supervisors => symbol_supervisors}}
  end

  defp flip_db_flag(symbol) do
    settings =
      from(nts in Hefty.Repo.NaiveTraderSetting, where: nts.symbol == ^symbol)
      |> Hefty.Repo.one()

    settings
    |> cast(%{:trading => !settings.trading}, [:trading])
    |> Hefty.Repo.update!()
  end

  defp start_symbol_supervisor(symbol) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        Hefty.Algos.Naive.DynamicSupervisor,
        {Hefty.Algos.Naive.SymbolSupervisor, symbol}
      )

    ref = Process.monitor(pid)

    {pid, ref}
  end

  defp stop_child({child_pid, ref}) do
    Process.demonitor(ref)

    :ok =
      DynamicSupervisor.terminate_child(
        Hefty.Algos.Naive.DynamicSupervisor,
        child_pid
      )
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {symbol, _} =
      state.symbol_supervisors
      |> Enum.find(false, fn {_, {process_pid, _}} -> process_pid == pid end)

    result = start_symbol_supervisor(symbol)

    symbol_supervisors = Map.put(state.symbol_supervisors, symbol, result)

    {:noreply, %{state | :symbol_supervisors => symbol_supervisors}}
  end
end
