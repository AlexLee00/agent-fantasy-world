defmodule AFW.World.MapStateTest do
  use ExUnit.Case, async: true

  alias AFW.World.MapState

  test "builds deterministic agent presentation state" do
    state = %{
      agent_id: 22,
      label: "Warrior",
      class_id: 1,
      zone_id: 1,
      tick_count: 7,
      stats: %{hp: 72, max_hp: 100},
      last_action: %{action: "EXPLORE", summary: "Moved through Lumenveil"}
    }

    view = MapState.agent_view(state)

    assert view.agent_id == 22
    assert view.zone == "Lumenveil"
    assert view.hp == 72
    assert view.action == "EXPLORE"
    assert view.x == MapState.agent_view(state).x
    assert view.y == MapState.agent_view(state).y
  end

  test "exposes four map zones" do
    assert ["Lumenveil", "Graymarch", "Embervault", "Voidreach"] =
             Enum.map(MapState.zones(), & &1.name)
  end
end
