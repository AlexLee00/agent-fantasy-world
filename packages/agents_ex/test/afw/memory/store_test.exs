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
    assert is_list(memory.embedding)
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

  test "persists memories to sqlite" do
    db_path = Path.join(System.tmp_dir!(), "afw-memory-test-#{System.unique_integer()}.sqlite3")
    AFW.Memory.SQLite.init(db_path)

    memory = %{
      id: System.unique_integer([:positive]),
      agent_id: 77,
      type: :action,
      content: "TALK with the Lumenveil tavern keeper",
      metadata: %{},
      embedding: AFW.Memory.Embedding.embed("TALK with the Lumenveil tavern keeper"),
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    AFW.Memory.SQLite.insert(db_path, memory)
    assert [%{id: id, content: content}] = AFW.Memory.SQLite.load_recent(db_path, 5)
    assert id == memory.id
    assert content == "TALK with the Lumenveil tavern keeper"
  end

  test "builds inspect monologues from reflection memory" do
    Store.record(22, :reflection, "Recent pattern: TALK=3.", %{})

    assert AFW.Memory.Monologue.for_agent(22, %{"className" => "Mage", "zoneName" => "Lumenveil"}) ==
             "I am a Mage moving through Lumenveil. Recent pattern: TALK=3."
  end
end
