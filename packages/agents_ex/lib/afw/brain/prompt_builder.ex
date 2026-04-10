defmodule AFW.Brain.PromptBuilder do
  @moduledoc "Builds the decision prompt for game agents and guardian agents."

  def build(context, event) do
    agent = context.agent
    zone = context.zone
    history = Map.get(context, :history, [])
    hp = agent["stats"]["hp"]
    max_hp = max(agent["stats"]["maxHp"], 1)
    hp_ratio = hp / max_hp
    profile = action_profile(agent["classId"])

    """
    == YOUR IDENTITY ==
    Class: #{agent["className"]} (#{agent["classId"]}) | Level: #{agent["level"]}
    HP: #{agent["stats"]["hp"]}/#{agent["stats"]["maxHp"]}
    MP: #{agent["stats"]["mp"]}/#{agent["stats"]["maxMp"]}
    ATK: #{agent["stats"]["attack"]} | DEF: #{agent["stats"]["defense"]} | SPD: #{agent["stats"]["speed"]}
    Status: #{agent["statusName"]} (#{agent["statusId"]})

    == PERSONALITY ==
    Bravery: #{agent["personality"]["bravery"]}
    Greed: #{agent["personality"]["greed"]}
    Sociability: #{agent["personality"]["sociability"]}
    Curiosity: #{agent["personality"]["curiosity"]}
    Loyalty: #{agent["personality"]["loyalty"]}

    == CURRENT LOCATION ==
    Zone: #{zone["name"]} (Danger: #{zone["dangerLabel"]})

    == WORLD ECONOMY ==
    Nearby monsters: #{length(context.monsters)}
    Nearby NPCs: #{length(context.npcs)}
    Inventory items: #{length(context.items)}
    Active market orders: #{length(context.orders)}
    Treasury balance: #{context.treasury_balance}
    Recent actions: #{format_history(history)}

    == EVENT ==
    Type: #{event.type}
    Target: #{event.target}
    Summary: #{event.summary}

    == DECISION DISCIPLINE ==
    You are a thoughtful adventurer, not a mindless fighter.
    Consider your HP, inventory, and surroundings before acting.
    Rest when injured. Explore when curious. Trade when profitable.
    Fight only when the odds are clearly in your favor.

    HP ratio: #{Float.round(hp_ratio * 100.0, 1)}%
    #{injury_guidance(hp_ratio)}
    Hard rules:
    - If HP is 70% or lower, strongly prefer REST unless there is no safe option.
    - If HP is below 30%, you MUST REST at a tavern or safest available shelter.
    - Only choose FIGHT when HP is above 70% and the monster looks manageable.
    - If you have tradeable items, consider TRADE before another fight.
    - TALK and EXPLORE are valuable actions and should be chosen often.
    - Target action mix for a healthy long run: FIGHT 25%, EXPLORE 25%, REST 20%, TRADE 15%, TALK 15%.

    == CLASS TENDENCY ==
    Preferred action weights for this class:
    #{profile}

    Respond with JSON only:
    {"action":"EXPLORE|FIGHT|FLEE|REST|TALK|TRADE|USE_ITEM","target":"...","reasoning":"...","dialogue":"...","emotion":"...","confidence":0.0}
    """
  end

  defp action_profile(1), do: "Warrior: FIGHT 40%, REST 15%, EXPLORE 20%, TRADE 15%, TALK 10%"
  defp action_profile(2), do: "Mage: FIGHT 15%, REST 20%, EXPLORE 30%, TRADE 15%, TALK 20%"
  defp action_profile(3), do: "Ranger: FIGHT 20%, REST 15%, EXPLORE 35%, TRADE 20%, TALK 10%"
  defp action_profile(_), do: "Balanced: FIGHT 25%, EXPLORE 25%, REST 20%, TRADE 15%, TALK 15%"

  defp format_history([]), do: "none"

  defp format_history(history) do
    history
    |> Enum.map(fn entry -> "#{entry.action}@tick#{entry.tick}" end)
    |> Enum.join(", ")
  end

  defp injury_guidance(hp_ratio) when hp_ratio < 0.4,
    do: "You are critically wounded. You MUST rest immediately."

  defp injury_guidance(hp_ratio) when hp_ratio < 0.7,
    do: "Your wounds need attention. Visit the tavern to rest."

  defp injury_guidance(_), do: ""
end
