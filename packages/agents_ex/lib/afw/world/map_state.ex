defmodule AFW.World.MapState do
  @moduledoc """
  2D presentation state for the LiveView/Phaser map.

  With the S1 open map, agents that carry a tile `:pos` are projected onto
  the 512x512 world (32px tiles) and their region comes from
  `AFW.World.Grid`. Agents without a position (legacy states, tests) fall
  back to the deterministic per-zone placement used by the Phase 1 viewer.
  """

  alias AFW.World.Grid

  @tile 32

  # legacy Phase 1 rectangles, kept as the no-position fallback
  @zones [
    %{id: 1, name: "Lumenveil", danger: "SAFE", x: 40, y: 40, width: 260, height: 170},
    %{id: 2, name: "Graymarch", danger: "MEDIUM", x: 340, y: 40, width: 260, height: 170},
    %{id: 3, name: "Embervault", danger: "DANGER", x: 40, y: 250, width: 260, height: 170},
    %{id: 4, name: "Voidreach", danger: "EXTREME", x: 340, y: 250, width: 260, height: 170}
  ]

  @doc "Open-map regions in pixel coordinates (hub first, from the Tiled map)."
  def zones do
    Enum.map(Grid.regions(), fn region ->
      %{
        id: region.id,
        name: region.name,
        danger: region.danger,
        x: region.x * @tile,
        y: region.y * @tile,
        width: region.w * @tile,
        height: region.h * @tile
      }
    end)
  end

  def agent_view(agent_state) do
    state = normalize(agent_state)
    agent_id = state[:agent_id] || state["agent_id"] || 0
    tick = state[:tick_count] || state["tick_count"] || 0
    zone_id = state[:zone_id] || state["zone_id"] || 1

    {x, y, region_id, region_name} =
      case state[:pos] || state["pos"] do
        {tx, ty} ->
          region = Grid.region_at(tx, ty)
          {tx * @tile + 16, ty * @tile + 16, region, Grid.region_name(region)}

        _no_pos ->
          zone = zone(zone_id)
          {px, py} = position(zone, agent_id, tick)
          {px, py, zone.id, zone.name}
      end

    stats = state[:stats] || state["stats"] || %{}
    last_action = state[:last_action] || state["last_action"] || %{}

    %{
      agent_id: agent_id,
      label: state[:label] || state["label"] || "Agent",
      class_id: state[:class_id] || state["class_id"],
      zone_id: region_id,
      zone: region_name,
      x: x,
      y: y,
      hp: stat(stats, :hp, "hp", 100),
      max_hp: stat(stats, :max_hp, "max_hp", stat(stats, :maxHp, "maxHp", 100)),
      action: last_action[:action] || last_action["action"] || "IDLE",
      summary: last_action[:summary] || last_action["summary"] || "",
      speech: speech(last_action),
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

  defp speech(last_action) do
    explicit = last_action[:dialogue] || last_action["dialogue"]

    cond do
      is_binary(explicit) and String.trim(explicit) != "" ->
        String.slice(explicit, 0, 90)

      (last_action[:action] || last_action["action"]) == "REST" ->
        "I need a safe place to recover."

      (last_action[:action] || last_action["action"]) == "TRADE" ->
        "The market may have an opening."

      (last_action[:action] || last_action["action"]) == "FIGHT" ->
        "I will test these odds carefully."

      (last_action[:action] || last_action["action"]) == "EXPLORE" ->
        "The roads may reveal something."

      true ->
        ""
    end
  end
end
