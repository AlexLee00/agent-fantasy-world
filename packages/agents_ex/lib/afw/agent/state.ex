defmodule AFW.Agent.State do
  @moduledoc "Runtime struct for a single AFW agent process."

  defstruct [
    :agent_id,
    :label,
    :class_id,
    :personality,
    :tick_interval,
    :brain_module,
    :zone_id,
    :level,
    :experience,
    :status,
    :stats,
    :last_action,
    :history,
    :wallet,
    :tick_count,
    :max_ticks,
    :post_combat_cooldown
  ]
end
