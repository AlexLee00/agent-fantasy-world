defmodule AFW.Combat.Stats do
  @moduledoc "Tracks combat attempts and outcomes in ETS and broadcasts snapshots for LiveView."

  use GenServer
  require Logger

  @table :afw_combat_stats
  @warning_threshold 0.7

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def record_attempt, do: GenServer.cast(__MODULE__, :attempt)
  def record_success, do: GenServer.cast(__MODULE__, :success)
  def record_failure, do: GenServer.cast(__MODULE__, :failure)
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  @impl true
  def init(_state) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    :ets.insert(@table, {:fight_attempts, 0})
    :ets.insert(@table, {:fight_successes, 0})
    :ets.insert(@table, {:fight_failures, 0})
    {:ok, %{}}
  end

  @impl true
  def handle_cast(:attempt, state) do
    increment(:fight_attempts)
    broadcast()
    {:noreply, state}
  end

  def handle_cast(:success, state) do
    increment(:fight_successes)
    maybe_warn()
    broadcast()
    {:noreply, state}
  end

  def handle_cast(:failure, state) do
    increment(:fight_failures)
    maybe_warn()
    broadcast()
    {:noreply, state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, export(), state}
  end

  defp increment(key) do
    :ets.update_counter(@table, key, {2, 1})
  end

  defp maybe_warn do
    stats = export()

    if stats.fight_attempts >= 5 and stats.success_rate < @warning_threshold do
      Logger.warning(
        "Combat success rate below target: #{Float.round(stats.success_rate * 100, 2)}% (#{stats.fight_successes}/#{stats.fight_attempts})"
      )
    end
  end

  defp broadcast do
    Phoenix.PubSub.broadcast(AFW.PubSub, "guardian", {:combat_stats, export()})
  end

  defp export do
    attempts = lookup(:fight_attempts)
    successes = lookup(:fight_successes)
    failures = lookup(:fight_failures)

    %{
      fight_attempts: attempts,
      fight_successes: successes,
      fight_failures: failures,
      success_rate: if(attempts == 0, do: 0.0, else: Float.round(successes / attempts, 4))
    }
  end

  defp lookup(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> value
      _ -> 0
    end
  end
end
