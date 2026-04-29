defmodule AFW.World.Combat do
  @moduledoc "Combat helpers for optimistic simulation plus eventual on-chain settlement."

  def simulate(context, event) do
    monster_id =
      get_in(event.metadata || %{}, [:monster_id]) ||
        get_in(event.metadata || %{}, ["monster_id"]) || 1

    agent_attack = get_in(context, [:agent, "stats", "attack"]) || 10
    agent_hp = get_in(context, [:agent, "stats", "hp"]) || 1

    monster_hp =
      get_in(event.metadata || %{}, [:hp]) || get_in(event.metadata || %{}, ["hp"]) || 1

    reward =
      get_in(event.metadata || %{}, [:soul_balance]) ||
        get_in(event.metadata || %{}, ["soul_balance"]) || 0

    win? = agent_attack * 5 >= monster_hp and agent_hp > 0
    soul_delta = if win?, do: reward, else: -div(reward, 2)

    damage =
      if(win?,
        do: 20 + rem(monster_hp + agent_attack, 26),
        else: 40 + rem(monster_hp + agent_attack, 31)
      )

    next_hp = max(agent_hp - damage, 1)

    %{
      summary:
        if(
          win?,
          do:
            "FIGHT #{event.target || "monster"}##{monster_id} -> WON +#{format_soul(reward)} SOUL, HP #{agent_hp}→#{next_hp}",
          else:
            "FIGHT #{event.target || "monster"}##{monster_id} -> LOST #{format_soul(abs(soul_delta))} SOUL, HP #{agent_hp}→#{next_hp}"
        ),
      optimistic_soul_delta: soul_delta,
      hp_after: next_hp,
      damage_taken: damage,
      state_changes: [%{field: :hp, value: next_hp}],
      success?: win?
    }
  end

  defp format_soul(amount), do: Float.round(amount / 1_000_000_000_000_000_000, 2)
end
