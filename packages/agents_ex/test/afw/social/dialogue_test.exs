defmodule AFW.Social.DialogueTest do
  use ExUnit.Case, async: false

  alias AFW.Social.Dialogue

  setup do
    Dialogue.clear_all()
    on_exit(fn -> Dialogue.clear_all() end)
    :ok
  end

  test "records recent dialogue and filters by agent" do
    {:ok, entry} = Dialogue.record(22, "Warrior", "The tavern road is safe.", %{tick: 3})

    assert entry.line == "The tavern road is safe."
    assert [%{agent_id: 22}] = Dialogue.recent(1)
    assert [%{speaker: "Warrior"}] = Dialogue.for_agent(22, 1)
    assert [] = Dialogue.for_agent(23, 1)
  end
end
