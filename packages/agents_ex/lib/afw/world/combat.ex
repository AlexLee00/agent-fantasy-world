defmodule AFW.World.Combat do
  @moduledoc "On-chain combat integration through CombatResolver."

  alias AFW.Chain.Client

  def resolve(context, event) do
    monster_id =
      get_in(event.metadata || %{}, [:monster_id]) ||
        get_in(event.metadata || %{}, ["monster_id"]) || 1

    case Client.resolve_combat(context.agent["agentId"], monster_id) do
      {:ok, payload} ->
        %{
          summary: "Combat resolved on-chain via CombatResolver (#{payload.tx_hash}).",
          status: :alive,
          tx_hash: payload.tx_hash
        }

      {:error, reason} ->
        %{
          summary: "Combat action was skipped after an on-chain revert: #{reason}",
          status: :alive
        }
    end
  end
end
