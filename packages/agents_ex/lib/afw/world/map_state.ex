defmodule AFW.World.MapState do
  @moduledoc "Deterministic 2D presentation state for the Phase 1 LiveView map."

  @zones [
    %{id: 1, name: "Lumenveil", danger: "SAFE", x: 40, y: 40, width: 260, height: 170},
    %{id: 2, name: "Graymarch", danger: "MEDIUM", x: 340, y: 40, width: 260, height: 170},
    %{id: 3, name: "Embervault", danger: "DANGER", x: 40, y: 250, width: 260, height: 170},
    %{id: 4, name: "Voidreach", danger: "EXTREME", x: 340, y: 250, width: 260, height: 170}
  ]

  def zones, do: @zones

  def agent_view(agent_state) do
    state = normalize(agent_state)
    agent_id = state[:agent_id] || state["agent_id"] || 0
    tick = state[:tick_count] || state["tick_count"] || 0
    zone_id = state[:zone_id] || state["zone_id"] || 1
    zone = zone(zone_id)
    {x, y} = position(zone, agent_id, tick)
    stats = state[:stats] || state["stats"] || %{}
    last_action = state[:last_action] || state["last_action"] || %{}

    %{
      agent_id: agent_id,
      label: state[:label] || state["label"] || "Agent",
      class_id: state[:class_id] || state["class_id"],
      zone_id: zone.id,
      zone: zone.name,
      x: x,
      y: y,
      hp: stat(stats, :hp, "hp", 100),
      max_hp: stat(stats, :max_hp, "max_hp", stat(stats, :maxHp, "maxHp", 100)),
      action: last_action[:action] || last_action["action"] || "IDLE",
      summary: last_action[:summary] || last_action["summary"] || "",
      tick: tick
    }
  end

  def zone(zone_id) do
    Enum.find(@zones, &(&1.id == zone_id)) || hd(@zones)
  end

  defp position(zone, agent_id, tick) do
    x = zone.x + 24 + rem(agent_id * 17 + tick * 7, max(zone.width - 48, 1))
    y = zone.y + 36 + rem(agent_id * 11 + tick * 5, max(zone.height - 60, 1))
    {x, y}
  end

  defp normalize(%_{} = struct), do: Map.from_struct(struct)
  defp normalize(map) when is_map(map), do: map
  defp normalize(_), do: %{}

  defp stat(stats, atom_key, string_key, default) do
    Map.get(stats, atom_key) || Map.get(stats, string_key) || default
  end
end
