defmodule AFW.Settlement.Metrics do
  @moduledoc "Tracks settlement lifecycle counts and durations across optimistic events."
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def record_submitted(event), do: GenServer.cast(__MODULE__, {:submitted, event})
  def record_retry(event), do: GenServer.cast(__MODULE__, {:retry, event})
  def record_confirmed(event), do: GenServer.cast(__MODULE__, {:confirmed, event})
  def record_discard(event, reason), do: GenServer.cast(__MODULE__, {:discarded, event, reason})
  def record_failed(event, reason), do: GenServer.cast(__MODULE__, {:failed, event, reason})
  def record_retargeted(type, reason), do: GenServer.cast(__MODULE__, {:retargeted, type, reason})
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  @impl true
  def init(_opts) do
    {:ok,
     %{
       events: %{},
       counts: %{total: 0, confirmed: 0, failed: 0, retrying: 0, discarded: 0, retargeted: 0},
       by_type: %{},
       recent_failures: [],
       discard_reasons: %{}
     }}
  end

  @impl true
  def handle_cast({:submitted, event}, state) do
    next_state =
      state
      |> put_event(event)
      |> update_counts(:total)
      |> update_type(event.type, :count, 1)

    {:noreply, next_state}
  end

  def handle_cast({:retry, _event}, state) do
    {:noreply, update_counts(state, :retrying)}
  end

  def handle_cast({:confirmed, event}, state) do
    settle_ms = settle_ms(event)

    next_state =
      state
      |> update_counts(:confirmed)
      |> update_type(event.type, :confirmed, 1)
      |> update_type(event.type, :settle_ms_total, settle_ms)
      |> drop_event(event.id)

    {:noreply, next_state}
  end

  def handle_cast({:discarded, event, reason}, state) do
    next_state =
      state
      |> update_counts(:discarded)
      |> update_type(event.type, :failed, 1)
      |> update_reason(reason)
      |> Map.update!(:recent_failures, fn failures ->
        [%{id: event.id, type: event.type, reason: inspect(reason)} | failures] |> Enum.take(20)
      end)
      |> drop_event(event.id)

    {:noreply, next_state}
  end

  def handle_cast({:failed, event, reason}, state) do
    next_state =
      state
      |> update_counts(:failed)
      |> update_type(event.type, :failed, 1)
      |> Map.update!(:recent_failures, fn failures ->
        [%{id: event.id, type: event.type, reason: inspect(reason)} | failures] |> Enum.take(20)
      end)
      |> drop_event(event.id)

    {:noreply, next_state}
  end

  def handle_cast({:retargeted, type, reason}, state) do
    next_state =
      state
      |> update_counts(:retargeted)
      |> update_reason(reason)
      |> update_type(type, :count, 0)

    {:noreply, next_state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, export(state), state}
  end

  defp put_event(state, event) do
    put_in(state, [:events, event.id], event)
  end

  defp drop_event(state, event_id) do
    update_in(state.events, &Map.delete(&1, event_id))
  end

  defp update_counts(state, key) do
    update_in(state.counts[key], &(&1 + 1))
  end

  defp update_type(state, type, key, delta) do
    update_in(state.by_type, fn by_type ->
      Map.update(by_type, type, %{count: 0, confirmed: 0, failed: 0, settle_ms_total: 0}, fn entry ->
        Map.update(entry, key, delta, &(&1 + delta))
      end)
    end)
  end

  defp update_reason(state, reason) do
    normalized = normalize_reason(reason)
    update_in(state.discard_reasons, &Map.update(&1, normalized, 1, fn count -> count + 1 end))
  end

  defp settle_ms(event) do
    max(DateTime.diff(DateTime.utc_now(), event.created_at, :millisecond), 0)
  end

  defp export(state) do
    %{
      totalEvents: state.counts.total,
      confirmedEvents: state.counts.confirmed,
      discardedEvents: state.counts.discarded,
      failedEvents: state.counts.failed,
      retargetedEvents: state.counts.retargeted,
      retryingEvents: state.counts.retrying,
      pendingEvents: map_size(state.events),
      averageSettleTimeMs: avg_total(state.by_type),
      byType:
        Map.new(state.by_type, fn {type, entry} ->
          avg =
            if entry.confirmed == 0 do
              0.0
            else
              Float.round(entry.settle_ms_total / entry.confirmed, 2)
            end

          {type,
           %{
             count: entry.count,
             confirmed: entry.confirmed,
             failed: entry.failed,
             avgSettleMs: avg
           }}
        end),
      recentFailures: state.recent_failures,
      discardReasons: state.discard_reasons
    }
  end

  defp normalize_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp normalize_reason(reason) when is_binary(reason), do: reason
  defp normalize_reason(reason), do: inspect(reason)

  defp avg_total(by_type) do
    totals =
      Enum.reduce(by_type, {0, 0}, fn {_type, entry}, {time_acc, count_acc} ->
        {time_acc + entry.settle_ms_total, count_acc + entry.confirmed}
      end)

    case totals do
      {_time, 0} -> 0.0
      {time, count} -> Float.round(time / count, 2)
    end
  end
end
