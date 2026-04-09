defmodule AFW.World.Event do
  @moduledoc "Generates agent-facing world events from on-chain snapshots."

  defstruct [:type, :title, :summary, :target, :metadata]

  def generate(context, _tick) do
    hp = get_in(context, [:agent, "stats", "hp"]) || 0
    max_hp = max(get_in(context, [:agent, "stats", "maxHp"]) || 1, 1)
    treasury_balance = context[:treasury_balance] || 0

    cond do
      treasury_balance >= 10_000 * 1_000_000_000_000_000_000 ->
        %__MODULE__{
          type: :world_boss,
          title: "World Boss awakened",
          summary: "EventTreasury has enough SOUL to unleash a world boss.",
          target: "world boss"
        }

      treasury_balance >= 5_000 * 1_000_000_000_000_000_000 ->
        %__MODULE__{
          type: :zone_event,
          title: "Zone boss surge",
          summary: "EventTreasury can empower a zone event right now.",
          target: "zone boss"
        }

      treasury_balance >= 1_000 * 1_000_000_000_000_000_000 ->
        %__MODULE__{
          type: :mini_event,
          title: "Rare spawn surge",
          summary: "EventTreasury can fund a mini event with boosted rewards.",
          target: "rare monster"
        }

      hp / max_hp < 0.3 ->
        %__MODULE__{
          type: :survival,
          title: "Critical condition",
          summary: "You are badly wounded and need immediate safety.",
          target: "tavern"
        }

      context.monsters != [] ->
        monster = List.first(context.monsters)

        %__MODULE__{
          type: :monster,
          title: "#{monster.name} roams nearby",
          summary: "A live monster can be challenged on-chain.",
          target: monster.name,
          metadata: monster
        }

      context.npcs != [] ->
        npc = List.first(context.npcs)

        %__MODULE__{
          type: :npc,
          title: "#{npc.name} is available",
          summary: "An NPC can offer rest, trade, or supplies.",
          target: npc.name,
          metadata: npc
        }

      context.orders != [] or context.items != [] ->
        %__MODULE__{
          type: :trade,
          title: "Marketplace opportunity",
          summary: "The local economy has active listings.",
          target: "marketplace"
        }

      true ->
        %__MODULE__{
          type: :explore,
          title: "Quiet roads",
          summary: "No pressing event dominates the zone.",
          target: "frontier path"
        }
    end
  end
end
