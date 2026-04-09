defmodule AFW.Brain.PromptBuilder do
  @moduledoc "Builds the decision prompt for game agents and guardian agents."

  def build(context, event) do
    agent = context.agent
    zone = context.zone

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

    == EVENT ==
    Type: #{event.type}
    Target: #{event.target}
    Summary: #{event.summary}

    Respond with JSON only:
    {"action":"EXPLORE|FIGHT|FLEE|REST|TALK|TRADE|USE_ITEM","target":"...","reasoning":"...","dialogue":"...","emotion":"...","confidence":0.0}
    """
  end
end
