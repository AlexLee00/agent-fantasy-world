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
      last_action: %{
        action: "EXPLORE",
        summary: "Moved through Lumenveil",
        dialogue: "The roads may reveal something useful."
      }
    }

    view = MapState.agent_view(state)

    assert view.agent_id == 22
    assert view.zone == "Lumenveil"
    assert view.hp == 72
    assert view.action == "EXPLORE"
    assert view.speech == "The roads may reveal something useful."
    assert view.x == MapState.agent_view(state).x
    assert view.y == MapState.agent_view(state).y
  end

  test "projects tile positions onto the open map and resolves the region" do
    state = %{
      agent_id: 7,
      label: "Ranger",
      class_id: 3,
      zone_id: 1,
      tick_count: 3,
      pos: {256, 256},
      stats: %{hp: 90, max_hp: 100},
      last_action: %{action: "EXPLORE", summary: "Wandering the plaza"}
    }

    view = MapState.agent_view(state)

    assert view.x == 256 * 32 + 16
    assert view.y == 256 * 32 + 16
    assert view.zone_id == 5
    assert view.zone == "Havenmoor"
  end

  test "exposes the five open-map regions with the hub first" do
    assert ["Havenmoor", "Lumenveil", "Graymarch", "Embervault", "Voidreach"] =
             Enum.map(MapState.zones(), & &1.name)
  end

  test "ships a Tiled open map matching the runtime regions" do
    path =
      Path.expand(
        "../../../priv/static/assets/maps/aethermoor_open.tmj",
        __DIR__
      )

    map = path |> File.read!() |> Jason.decode!()
    region_layer = Enum.find(map["layers"], &(&1["name"] == "regions"))

    assert map["type"] == "map"
    assert map["width"] == 512 and map["height"] == 512
    assert length(region_layer["objects"]) == 5

    assert Enum.map(region_layer["objects"], & &1["name"]) ==
             Enum.map(MapState.zones(), & &1.name)
  end
end
