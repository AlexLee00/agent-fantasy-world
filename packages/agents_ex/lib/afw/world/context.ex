defmodule AFW.World.Context do
  @moduledoc "Reference world data used to seed and render the Elixir runtime."

  def zone(1), do: %{"zoneId" => 1, "name" => "Lumenveil", "dangerLabel" => "SAFE"}
  def zone(2), do: %{"zoneId" => 2, "name" => "Graymarch", "dangerLabel" => "MEDIUM"}
  def zone(3), do: %{"zoneId" => 3, "name" => "Embervault", "dangerLabel" => "DANGER"}
  def zone(4), do: %{"zoneId" => 4, "name" => "Voidreach", "dangerLabel" => "EXTREME"}
  def zone(_), do: zone(1)

  def monsters_for_zone(1),
    do: [
      %{
        monster_id: 1,
        name: "Goblin Scout",
        atk: 10,
        def: 5,
        hp: 50,
        soul_balance: 10 * 1_000_000_000_000_000_000,
        danger_level: 1
      }
    ]

  def monsters_for_zone(2),
    do: [
      %{
        monster_id: 2,
        name: "Dark Archer",
        atk: 18,
        def: 10,
        hp: 150,
        soul_balance: 30 * 1_000_000_000_000_000_000,
        danger_level: 2
      }
    ]

  def monsters_for_zone(3),
    do: [
      %{
        monster_id: 3,
        name: "Fire Drake",
        atk: 30,
        def: 18,
        hp: 400,
        soul_balance: 120 * 1_000_000_000_000_000_000,
        danger_level: 3
      }
    ]

  def monsters_for_zone(4),
    do: [
      %{
        monster_id: 4,
        name: "Void Wyrm",
        atk: 60,
        def: 40,
        hp: 1_200,
        soul_balance: 300 * 1_000_000_000_000_000_000,
        danger_level: 4
      }
    ]

  def monsters_for_zone(_), do: []

  def npcs_for_zone(1),
    do: [
      %{npc_id: 1, name: "Lumenveil Tavern", role: "TAVERN"},
      %{npc_id: 2, name: "Lumenveil Shop", role: "SHOP"},
      %{npc_id: 3, name: "Lumenveil Smithy", role: "SMITHY"}
    ]

  def npcs_for_zone(2),
    do: [
      %{npc_id: 4, name: "Graymarch Tavern", role: "TAVERN"},
      %{npc_id: 5, name: "Graymarch Shop", role: "SHOP"}
    ]

  def npcs_for_zone(3),
    do: [
      %{npc_id: 6, name: "Embervault Tavern", role: "TAVERN"},
      %{npc_id: 7, name: "Embervault Shop", role: "SHOP"}
    ]

  def npcs_for_zone(4),
    do: [
      %{npc_id: 8, name: "Voidreach Tavern", role: "TAVERN"},
      %{npc_id: 9, name: "Voidreach Shop", role: "SHOP"}
    ]

  def npcs_for_zone(_), do: []

  def seed_item_inventory do
    [
      %{item_id: 1, name: "Basic Health Potion", tradeable: true},
      %{item_id: 2, name: "Iron Sword", tradeable: true}
    ]
  end

  def sample_orders do
    [
      %{
        order_id: 1,
        item_id: 1,
        amount: 1,
        price_in_soul: 5 * 1_000_000_000_000_000_000,
        seller: "0xfeed"
      }
    ]
  end
end
