defmodule AFW.World.Combat do
  @moduledoc "On-chain combat integration through CombatResolver."

  alias AFW.Chain.Client
  alias AFW.Combat.Stats

  def resolve(context, event) do
    monster_id =
      get_in(event.metadata || %{}, [:monster_id]) ||
        get_in(event.metadata || %{}, ["monster_id"]) || 1

    Stats.record_attempt()

    case Client.resolve_combat(context.agent["agentId"], monster_id) do
      {:ok, payload} ->
        Stats.record_success()

        %{
          summary: "FIGHT #{event.target || "monster"}##{monster_id} -> resolved on-chain (#{payload.tx_hash})",
          status: :alive,
          tx_hash: payload.tx_hash,
          success?: true
        }

      {:error, reason} ->
        Stats.record_failure()

        %{
          summary: "FIGHT failed for monster##{monster_id}: #{reason}",
          status: :alive,
          success?: false,
          error: reason
        }
    end
  end
end
