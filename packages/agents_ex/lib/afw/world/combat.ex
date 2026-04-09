defmodule AFW.World.Combat do
  @moduledoc "On-chain combat integration through CombatResolver."

  alias AFW.Chain.Client

  def resolve(context, event) do
    monster_id =
      get_in(event.metadata || %{}, [:monster_id]) ||
        get_in(event.metadata || %{}, ["monster_id"]) || 1

    {:ok, payload} = Client.resolve_combat(context.agent["agentId"], monster_id)

    %{
      summary: "Combat resolved on-chain via CombatResolver (#{payload.tx_hash}).",
      status: :alive,
      tx_hash: payload.tx_hash
    }
  end
end
