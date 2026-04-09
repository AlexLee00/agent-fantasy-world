defmodule AFW.Settlement.Event do
  @moduledoc "Settlement event structure and helper builders."

  defstruct [:id, :type, :priority, :agent_id, :data, :status, :created_at, :retry_count]

  def new(attrs) do
    %__MODULE__{
      id: attrs[:id] || to_string(System.unique_integer([:positive, :monotonic])),
      type: attrs[:type] || :deferred,
      priority: attrs[:priority] || :normal,
      agent_id: attrs[:agent_id],
      data: Map.new(attrs[:data] || %{}),
      status: attrs[:status] || :pending,
      created_at: attrs[:created_at] || DateTime.utc_now(),
      retry_count: attrs[:retry_count] || 0
    }
  end

  def priority_for(:agent_death), do: :immediate
  def priority_for(:world_boss_kill), do: :immediate
  def priority_for(:combat_result), do: :normal
  def priority_for(:npc_purchase), do: :normal
  def priority_for(:marketplace_trade), do: :batch
  def priority_for(_), do: :deferred
end
