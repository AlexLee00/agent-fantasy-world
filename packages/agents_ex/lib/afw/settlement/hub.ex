defmodule AFW.Settlement.Hub do
  @moduledoc "Game-to-chain settlement bridge with optimistic updates, locks, queued batches, and reconciliation."

  use GenServer
  require Logger

  alias AFW.Settlement.{Event, Metrics, Reconciler, Settler, State}

  @queue :event_queue
  @targets :targeted_monsters
  @normal_interval 30_000
  @batch_interval 300_000
  @deferred_interval 1_800_000
  @reconcile_interval 30_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def submit_event(event), do: GenServer.cast(__MODULE__, {:submit, event})
  def queued_events, do: GenServer.call(__MODULE__, :queued_events)
  def settle_now(priority), do: GenServer.call(__MODULE__, {:settle_now, priority}, 600_000)

  def queued_events_snapshot do
    case :ets.whereis(@queue) do
      :undefined -> []
      _ -> :ets.tab2list(@queue) |> Enum.map(fn {_key, event} -> event end)
    end
  end

  @impl true
  def init(_state) do
    State.ensure_tables!()
    ensure_queue!()
    ensure_targets!()
    schedule(:normal)
    schedule(:batch)
    schedule(:deferred)
    schedule_reconcile()
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:submit, attrs}, state) do
    event = normalize(attrs)
    State.apply_optimistic(event)
    Metrics.record_submitted(event)
    State.add_lock(event.id, event.agent_id, outgoing_lock_amount(event))
    insert_event(event)

    Phoenix.PubSub.broadcast(
      AFW.PubSub,
      "agents",
      {:settlement_optimistic, event.agent_id, State.settlement_summary(event.agent_id)}
    )

    if event.priority == :immediate do
      settle_or_retry(event)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:settle, priority}, state) do
    queued(priority) |> Enum.each(&settle_or_retry/1)
    schedule(priority)
    {:noreply, state}
  end

  def handle_info(:reconcile, state) do
    Reconciler.reconcile()
    schedule_reconcile()
    {:noreply, state}
  end

  @impl true
  def handle_call(:queued_events, _from, state) do
    {:reply, all_events(), state}
  end

  def handle_call({:settle_now, priority}, _from, state) do
    events = queued(priority)
    Enum.each(events, &settle_or_retry/1)

    {:reply, %{priority: priority, attempted: length(events), pending: length(queued(priority))},
     state}
  end

  defp settle_or_retry(event) do
    delete_event(event)

    case Settler.settle_event(event) do
      {:ok, _payload} ->
        :ok

      {:error, reason} ->
        if event.retry_count < 3 do
          Logger.warning(
            "Settlement retry #{event.retry_count + 1} for #{event.id}: #{inspect(reason)}"
          )

          Metrics.record_retry(event)
          insert_event(%{event | retry_count: event.retry_count + 1, status: :retrying})
        else
          State.rollback_event(event)
          State.release_lock(event.id, event.agent_id)
          Metrics.record_failed(event, reason)

          Phoenix.PubSub.broadcast(
            AFW.PubSub,
            "agents",
            {:settlement_failed, event.agent_id, event.id, reason}
          )
        end
    end
  end

  defp normalize(%Event{} = event), do: event
  defp normalize(attrs), do: Event.new(Enum.into(attrs, []))

  defp outgoing_lock_amount(event) do
    Map.get(event.data, :soul_changes, [])
    |> Enum.filter(fn change -> change.agent_id == event.agent_id and change.delta < 0 end)
    |> Enum.reduce(0, fn change, acc -> acc + abs(change.delta) end)
  end

  defp insert_event(event) do
    key = {DateTime.to_unix(event.created_at, :microsecond), event.id}
    :ets.insert(@queue, {key, event})
  end

  defp delete_event(event) do
    key = {DateTime.to_unix(event.created_at, :microsecond), event.id}
    :ets.delete(@queue, key)
  end

  defp queued(priority) do
    all_events() |> Enum.filter(&(&1.priority == priority))
  end

  defp all_events do
    ensure_queue!()
    :ets.tab2list(@queue) |> Enum.map(fn {_key, event} -> event end)
  end

  defp schedule(:normal), do: Process.send_after(self(), {:settle, :normal}, @normal_interval)
  defp schedule(:batch), do: Process.send_after(self(), {:settle, :batch}, @batch_interval)

  defp schedule(:deferred),
    do: Process.send_after(self(), {:settle, :deferred}, @deferred_interval)

  defp schedule_reconcile, do: Process.send_after(self(), :reconcile, @reconcile_interval)

  defp ensure_queue! do
    case :ets.whereis(@queue) do
      :undefined -> :ets.new(@queue, [:named_table, :public, :ordered_set])
      _ -> @queue
    end
  end

  defp ensure_targets! do
    case :ets.whereis(@targets) do
      :undefined ->
        :ets.new(@targets, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        @targets
    end
  end
end
