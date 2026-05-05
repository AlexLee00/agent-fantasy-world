defmodule AFW.World.EventLifecycle do
  @moduledoc """
  Local lifecycle guard for treasury-backed world events.

  The EventTreasury balance is durable on-chain, but the agent-facing event should not
  dominate every tick while a threshold remains funded. This module keeps a local,
  off-chain cooldown per threshold so Phase 1 demos can keep normal exploration,
  dialogue, rest, and trade behavior visible even when testnet treasury state is high.
  """

  @table :afw_world_event_lifecycle
  @one_soul 1_000_000_000_000_000_000
  @cooldown_ms 30 * 60 * 1_000

  @type threshold :: :world_boss | :zone_event | :mini_event

  def treasury_event(balance, now_ms \\ System.monotonic_time(:millisecond))

  def treasury_event(balance, now_ms) when is_integer(balance) do
    ensure_table!()

    case threshold(balance) do
      nil ->
        nil

      threshold ->
        if on_cooldown?(threshold, now_ms) do
          nil
        else
          :ets.insert(@table, {threshold, now_ms})
          threshold
        end
    end
  end

  def treasury_event(_balance, _now_ms), do: nil

  def reset do
    ensure_table!()
    :ets.delete_all_objects(@table)
    :ok
  end

  def threshold(balance) when balance >= 10_000 * @one_soul, do: :world_boss
  def threshold(balance) when balance >= 5_000 * @one_soul, do: :zone_event
  def threshold(balance) when balance >= 1_000 * @one_soul, do: :mini_event
  def threshold(_balance), do: nil

  defp on_cooldown?(threshold, now_ms) do
    case :ets.lookup(@table, threshold) do
      [{^threshold, seen_at}] -> now_ms - seen_at < cooldown_ms()
      _ -> false
    end
  end

  defp cooldown_ms do
    Application.get_env(:afw, :world_event_cooldown_ms, @cooldown_ms)
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        @table
    end
  end
end
