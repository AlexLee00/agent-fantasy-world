defmodule AFW.Brain.PromptBuilderTest do
  use ExUnit.Case, async: true

  test "builds a prompt with identity and event sections" do
    context = %{
      agent: %{
        "className" => "Warrior",
        "classId" => 1,
        "level" => 1,
        "stats" => %{
          "hp" => 100,
          "maxHp" => 100,
          "mp" => 50,
          "maxMp" => 50,
          "attack" => 20,
          "defense" => 15,
          "speed" => 10
        },
        "statusName" => "ALIVE",
        "statusId" => 1,
        "personality" => %{
          "bravery" => 90,
          "greed" => 10,
          "sociability" => 30,
          "curiosity" => 80,
          "loyalty" => 50
        }
      },
      zone: %{"name" => "Lumenveil", "dangerLabel" => "SAFE"},
      monsters: [],
      npcs: [],
      items: [],
      orders: [],
      treasury_balance: 0,
      memories: [
        %{type: :reflection, content: "Recent pattern: EXPLORE=2, TALK=1."}
      ]
    }

    event = %AFW.World.Event{type: :explore, target: "path", summary: "The roads are quiet."}
    prompt = AFW.Brain.PromptBuilder.build(context, event)
    assert prompt =~ "YOUR IDENTITY"
    assert prompt =~ "WORLD ECONOMY"
    assert prompt =~ "RELEVANT MEMORY"
    assert prompt =~ "Recent pattern"
    assert prompt =~ "The roads are quiet."
  end
end
