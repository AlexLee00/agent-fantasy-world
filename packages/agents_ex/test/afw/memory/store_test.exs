defmodule AFW.Memory.StoreTest do
  use ExUnit.Case, async: false

  alias AFW.Memory.{Reflection, Store}

  setup do
    Store.clear_all()
    on_exit(fn -> Store.clear_all() end)
    :ok
  end

  test "records and retrieves recent memories" do
    {:ok, memory} = Store.record(22, :action, "EXPLORE Lumenveil frontier", %{action: "EXPLORE"})

    assert memory.agent_id == 22
    assert [%{content: "EXPLORE Lumenveil frontier"}] = Store.recent(22, 1)
  end

  test "retrieves relevant memories by token overlap and falls back to recent" do
    Store.record(22, :action, "REST at the tavern after combat", %{action: "REST"})
    Store.record(22, :action, "TRADE potion at marketplace", %{action: "TRADE"})

    assert [%{content: "REST at the tavern after combat"} | _] =
             Store.relevant(22, "injured tavern", 2)

    assert length(Store.relevant(22, "unmatched-query", 2)) == 2
  end

  test "creates a reflection memory" do
    Store.record(22, :action, "FIGHT nearby monster", %{action: "FIGHT"})
    Store.record(22, :action, "REST at tavern", %{action: "REST"})

    assert {:ok, %{type: :reflection, content: content}} = Reflection.reflect(22, 50)
    assert content =~ "Recent pattern"
  end
end
