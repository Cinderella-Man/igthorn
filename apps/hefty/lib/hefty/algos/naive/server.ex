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

  def update_status(symbol, status) do
    GenServer.cast(__MODULE__, {:update_status, symbol, status})
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
        where: nts.platform == "Binance" and nts.status == "ON"
      )
      |> Hefty.Repo.all()
      |> Enum.map(&{&1.symbol, start_symbol_supervisor(&1.symbol)})
      |> Enum.into(%{})

    {:noreply, %State{:symbol_supervisors => symbol_supervisors}}
  end

  def handle_cast(
    {:update_status, symbol, status},
    %State{
      :symbol_supervisors => symbol_supervisors
    } = state
  ) do
    update_db_status(symbol, status)

    current_state = Map.get(symbol_supervisors, symbol)

    new_state = case status do
      "OFF" -> case current_state do
        nil -> Logger.info("Trading on #{symbol} is already disabled")
               state
        _   -> stop_trading(symbol, current_state, state)
      end

      "ON" -> case current_state do
        nil -> start_trading(symbol, state)
        _ -> Logger.info("Trading was still running. No need to do anything")
             state
      end

      _ -> Logger.info("Graceful shutdown initialized on symbol #{symbol}")
           state
    end

    {:noreply, new_state}
  end

  defp stop_trading(symbol, ref, state) do
    Logger.info("Stopping supervision tree to cancel trading on symbol #{symbol}")
    stop_child(ref)
    symbol_supervisors = Map.delete(state.symbol_supervisors, symbol)
    %{state | :symbol_supervisors => symbol_supervisors}
  end

  defp start_trading(symbol, state) do
    Logger.info("Starting new supervision tree to trade on symbol #{symbol}")
    result = start_symbol_supervisor(symbol)
    symbol_supervisors = Map.put(state.symbol_supervisors, symbol, result)
    %{state | :symbol_supervisors => symbol_supervisors}
  end

  defp update_db_status(symbol, status) do
    settings =
      from(nts in Hefty.Repo.NaiveTraderSetting, where: nts.symbol == ^symbol)
      |> Hefty.Repo.one()

    new_settings = settings
    |> cast(%{:status => status}, [:status])
    |> Hefty.Repo.update!()

    Hefty.Algos.Naive.Leader.update_settings(symbol, new_settings)

    new_settings
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
