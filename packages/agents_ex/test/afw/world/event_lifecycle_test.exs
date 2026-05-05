defmodule AFW.World.EventLifecycleTest do
  use ExUnit.Case, async: false

  alias AFW.World.{Event, EventLifecycle}

  @one_soul 1_000_000_000_000_000_000

  setup do
    EventLifecycle.reset()
    on_exit(fn -> EventLifecycle.reset() end)
    :ok
  end

  test "emits a treasury event once per cooldown window" do
    assert :world_boss == EventLifecycle.treasury_event(10_000 * @one_soul, 1_000)
    assert nil == EventLifecycle.treasury_event(10_000 * @one_soul, 2_000)

    later = 1_000 + Application.get_env(:afw, :world_event_cooldown_ms, 1_800_000) + 1
    assert :world_boss == EventLifecycle.treasury_event(10_000 * @one_soul, later)
  end

  test "falls back to normal agent-facing events during cooldown" do
    context = %{
      agent: %{"stats" => %{"hp" => 100, "maxHp" => 100}},
      monsters: [%{name: "Goblin Scout"}],
      npcs: [],
      items: [],
      orders: [],
      treasury_balance: 10_000 * @one_soul
    }

    assert %Event{type: :world_boss} = Event.generate(context, 1)
    assert %Event{type: :monster, target: "Goblin Scout"} = Event.generate(context, 2)
  end
end
