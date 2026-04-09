defmodule AFW.Settlement.State do
  @moduledoc "Reads and mutates optimistic settlement state stored in ETS."

  alias AFW.Chain.Client

  @optimistic_table :optimistic_state
  @locks_table :pending_locks

  def ensure_tables! do
    ensure_table(@optimistic_table)
    ensure_table(@locks_table)
    :ok
  end

  def get_agent_view(agent_id) do
    ensure_tables!()
    snapshot = Client.snapshot(agent_id)
    {display_total, pending} = display_soul(agent_id)
    optimistic_state = optimistic_state(agent_id)

    merged_agent =
      snapshot.agent
      |> Map.put("displaySoul", display_total)
      |> Map.put("pendingSoul", pending)
      |> Map.put("spendableSoul", spendable_soul(agent_id))
      |> merge_offchain(optimistic_state[:offchain] || %{})

    Map.merge(snapshot, %{agent: merged_agent, settlement: settlement_summary(agent_id)})
  end

  def spendable_soul(agent_id) do
    max(confirmed_soul(agent_id) - get_locked_soul(agent_id), 0)
  end

  def display_soul(agent_id) do
    confirmed = confirmed_soul(agent_id)
    optimistic = get_optimistic_delta(agent_id)
    {confirmed + optimistic, optimistic}
  end

  def confirmed_soul(agent_id) do
    state = optimistic_state(agent_id)

    case Map.get(state, :confirmed_soul) do
      nil ->
        confirmed = fetch_confirmed_soul(agent_id)
        put_state(agent_id, Map.put(state, :confirmed_soul, confirmed))
        confirmed

      value ->
        value
    end
  end

  def correct_confirmed(agent_id, value) do
    state = optimistic_state(agent_id)
    put_state(agent_id, Map.put(state, :confirmed_soul, value))
  end

  def apply_optimistic(event) do
    state = optimistic_state(event.agent_id)
    delta = optimistic_delta_for(event)

    recent =
      [event_summary(event, :pending) | Map.get(state, :recent_events, [])]
      |> Enum.take(10)

    next_state =
      state
      |> Map.put(:optimistic_delta, Map.get(state, :optimistic_delta, 0) + delta)
      |> Map.put(:offchain, apply_state_changes(Map.get(state, :offchain, %{}), state_changes(event)))
      |> Map.put(:recent_events, recent)
      |> Map.put(:pending_events, Map.put(Map.get(state, :pending_events, %{}), event.id, event))

    put_state(event.agent_id, next_state)
  end

  def confirm_event(event) do
    state = optimistic_state(event.agent_id)
    confirmed = fetch_confirmed_soul(event.agent_id)

    next_state =
      state
      |> Map.put(:confirmed_soul, confirmed)
      |> Map.put(:optimistic_delta, recalc_delta(state, event.id))
      |> Map.put(:pending_events, Map.delete(Map.get(state, :pending_events, %{}), event.id))
      |> Map.put(:recent_events, [event_summary(event, :confirmed) | Enum.reject(Map.get(state, :recent_events, []), &(&1.id == event.id))] |> Enum.take(10))

    put_state(event.agent_id, next_state)
  end

  def rollback_event(event) do
    state = optimistic_state(event.agent_id)

    next_state =
      state
      |> Map.put(:optimistic_delta, recalc_delta(state, event.id))
      |> Map.put(:pending_events, Map.delete(Map.get(state, :pending_events, %{}), event.id))
      |> Map.put(:recent_events, [event_summary(event, :failed) | Enum.reject(Map.get(state, :recent_events, []), &(&1.id == event.id))] |> Enum.take(10))

    put_state(event.agent_id, next_state)
  end

  def add_lock(event_id, agent_id, amount) when amount > 0 do
    ensure_tables!()
    :ets.insert(@locks_table, {{agent_id, event_id}, amount})
    :ok
  end

  def add_lock(_event_id, _agent_id, _amount), do: :ok

  def release_lock(event_id, agent_id) do
    ensure_tables!()
    :ets.delete(@locks_table, {agent_id, event_id})
    :ok
  end

  def settlement_summary(agent_id) do
    {display_total, pending} = display_soul(agent_id)
    %{
      confirmedSoul: confirmed_soul(agent_id),
      pendingSoul: pending,
      displaySoul: display_total,
      spendableSoul: spendable_soul(agent_id),
      recentEvents: Map.get(optimistic_state(agent_id), :recent_events, [])
    }
  end

  def optimistic_state(agent_id) do
    ensure_tables!()

    case :ets.lookup(@optimistic_table, agent_id) do
      [{^agent_id, state}] -> state
      _ -> %{pending_events: %{}, optimistic_delta: 0, offchain: %{}, recent_events: []}
    end
  end

  def all_agent_ids do
    ensure_tables!()
    :ets.tab2list(@optimistic_table) |> Enum.map(fn {agent_id, _} -> agent_id end)
  end

  def get_locked_soul(agent_id) do
    ensure_tables!()

    :ets.tab2list(@locks_table)
    |> Enum.reduce(0, fn
      {{^agent_id, _}, amount}, acc -> acc + amount
      _, acc -> acc
    end)
  end

  def get_optimistic_delta(agent_id) do
    Map.get(optimistic_state(agent_id), :optimistic_delta, 0)
  end

  defp fetch_confirmed_soul(agent_id) do
    agent = Client.get_agent(agent_id)
    Client.get_soul_balance(agent["observer"])
  end

  defp optimistic_delta_for(event) do
    event
    |> soul_changes()
    |> Enum.filter(fn change -> (change[:agent_id] || change["agent_id"]) == event.agent_id end)
    |> Enum.reduce(0, fn change, acc -> acc + (change[:delta] || change["delta"] || 0) end)
  end

  defp state_changes(event), do: Map.get(event.data, :state_changes) || Map.get(event.data, "state_changes") || []
  defp soul_changes(event), do: Map.get(event.data, :soul_changes) || Map.get(event.data, "soul_changes") || []

  defp apply_state_changes(offchain, changes) do
    Enum.reduce(changes, offchain, fn change, acc ->
      field = to_string(change[:field] || change["field"])
      value = change[:value] || change["value"]
      Map.put(acc, field, value)
    end)
  end

  defp recalc_delta(state, drop_id) do
    state
    |> Map.get(:pending_events, %{})
    |> Map.delete(drop_id)
    |> Map.values()
    |> Enum.reduce(0, fn event, acc -> acc + optimistic_delta_for(event) end)
  end

  defp event_summary(event, status) do
    %{
      id: event.id,
      type: event.type,
      status: status,
      summary: Map.get(event.data, :summary) || Map.get(event.data, "summary") || Atom.to_string(event.type)
    }
  end

  defp merge_offchain(agent, offchain) do
    Enum.reduce(offchain, agent, fn {field, value}, acc -> Map.put(acc, field, value) end)
  end

  defp put_state(agent_id, state) do
    :ets.insert(@optimistic_table, {agent_id, state})
    state
  end

  defp ensure_table(table) do
    case :ets.whereis(table) do
      :undefined -> :ets.new(table, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])
      _ -> table
    end
  end
end
