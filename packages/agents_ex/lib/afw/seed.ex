defmodule AFW.Seed do
  @moduledoc "Seeds item types, monster types, spawned monsters, NPCs, and NPC price tables on-chain."

  alias AFW.Chain.Client

  @one_soul 1_000_000_000_000_000_000

  def run do
    IO.puts("Seeding AFW world via Elixir runtime...")
    IO.puts("Using deployer #{Client.account_address()} on Base Sepolia.")

    item_ids =
      item_specs()
      |> Enum.map(fn spec ->
        {:ok, result} =
          Client.register_item_type(
            spec.name,
            spec.category,
            spec.tier,
            spec.min_stat,
            spec.max_stat,
            spec.tradeable
          )

        IO.puts("Registered item #{spec.name} -> itemId #{result.item_id}")
        {spec.name, result.item_id}
      end)
      |> Map.new()

    monster_types =
      monster_specs()
      |> Enum.map(fn spec ->
        {:ok, result} = Client.register_monster_type(spec)
        IO.puts("Registered monster #{spec.name} -> typeId #{result.type_id}")
        {spec.name, result.type_id}
      end)
      |> Map.new()

    Enum.each(monster_spawns(monster_types), fn {name, zone_id} ->
      {:ok, result} = Client.spawn_monster(Map.fetch!(monster_types, name), zone_id)
      IO.puts("Spawned monster #{name} in zone #{zone_id} -> monsterId #{result.monster_id}")
    end)

    npc_types =
      npc_specs()
      |> Enum.map(fn spec ->
        {:ok, result} = Client.register_npc_type(spec.name, spec.role, spec.zone_id)
        IO.puts("Registered NPC #{spec.name} -> typeId #{result.type_id}")
        {{spec.name, spec.zone_id}, %{type_id: result.type_id, role: spec.role}}
      end)
      |> Map.new()

    npc_ids =
      npc_specs()
      |> Enum.map(fn spec ->
        {:ok, result} =
          Client.spawn_npc(
            npc_types[{spec.name, spec.zone_id}].type_id,
            spec.zone_id,
            spec.initial_soul
          )

        IO.puts("Spawned NPC #{spec.name} in zone #{spec.zone_id} -> npcId #{result.npc_id}")
        {{spec.name, spec.zone_id}, result.npc_id}
      end)
      |> Map.new()

    Enum.each(price_specs(item_ids, npc_ids), fn %{npc_key: npc_key, item_name: item_name, price: price} ->
      {:ok, _result} =
        Client.set_npc_price(Map.fetch!(npc_ids, npc_key), Map.fetch!(item_ids, item_name), price)

      IO.puts("Set price #{elem(npc_key, 0)} / #{item_name} -> #{price}")
    end)

    :ok
  end

  defp item_specs do
    [
      %{name: "Basic Health Potion", category: "CONSUMABLE", tier: 1, min_stat: 4, max_stat: 8, tradeable: true},
      %{name: "Iron Sword", category: "WEAPON", tier: 1, min_stat: 6, max_stat: 10, tradeable: true},
      %{name: "Leather Armor", category: "ARMOR", tier: 1, min_stat: 5, max_stat: 9, tradeable: true},
      %{name: "Fire Sword", category: "WEAPON", tier: 2, min_stat: 12, max_stat: 22, tradeable: true},
      %{name: "Steel Shield", category: "ARMOR", tier: 2, min_stat: 10, max_stat: 18, tradeable: true}
    ]
  end

  defp monster_specs do
    [
      %{name: "Goblin Scout", danger_level: 1, min_hp: 30, max_hp: 70, min_atk: 8, max_atk: 12, min_def: 4, max_def: 8, min_soul: 5, max_soul: 10},
      %{name: "Forest Wolf", danger_level: 1, min_hp: 50, max_hp: 90, min_atk: 10, max_atk: 15, min_def: 6, max_def: 10, min_soul: 8, max_soul: 15},
      %{name: "Dark Archer", danger_level: 2, min_hp: 100, max_hp: 200, min_atk: 15, max_atk: 22, min_def: 10, max_def: 15, min_soul: 20, max_soul: 35},
      %{name: "Stone Golem", danger_level: 2, min_hp: 150, max_hp: 280, min_atk: 13, max_atk: 20, min_def: 12, max_def: 18, min_soul: 24, max_soul: 45},
      %{name: "Fire Drake", danger_level: 3, min_hp: 250, max_hp: 500, min_atk: 25, max_atk: 35, min_def: 18, max_def: 28, min_soul: 80, max_soul: 120},
      %{name: "Shadow Knight", danger_level: 3, min_hp: 300, max_hp: 550, min_atk: 22, max_atk: 38, min_def: 20, max_def: 30, min_soul: 90, max_soul: 140},
      %{name: "Void Wyrm", danger_level: 4, min_hp: 600, max_hp: 1_500, min_atk: 40, max_atk: 70, min_def: 28, max_def: 40, min_soul: 220, max_soul: 350},
      %{name: "Abyssal Lord", danger_level: 4, min_hp: 800, max_hp: 1_800, min_atk: 50, max_atk: 75, min_def: 35, max_def: 48, min_soul: 260, max_soul: 420}
    ]
  end

  defp monster_spawns(monster_types) do
    Enum.map(monster_types, fn {name, _type_id} ->
      zone_id =
        cond do
          name in ["Goblin Scout", "Forest Wolf"] -> 1
          name in ["Dark Archer", "Stone Golem"] -> 2
          name in ["Fire Drake", "Shadow Knight"] -> 3
          true -> 4
        end

      {name, zone_id}
    end)
  end

  defp npc_specs do
    [
      %{name: "Lumenveil Tavern", role: "TAVERN", zone_id: 1, initial_soul: 25 * @one_soul},
      %{name: "Lumenveil Shop", role: "SHOP", zone_id: 1, initial_soul: 25 * @one_soul},
      %{name: "Lumenveil Smithy", role: "SMITHY", zone_id: 1, initial_soul: 30 * @one_soul},
      %{name: "Graymarch Tavern", role: "TAVERN", zone_id: 2, initial_soul: 30 * @one_soul},
      %{name: "Graymarch Shop", role: "SHOP", zone_id: 2, initial_soul: 30 * @one_soul},
      %{name: "Embervault Tavern", role: "TAVERN", zone_id: 3, initial_soul: 35 * @one_soul},
      %{name: "Embervault Shop", role: "SHOP", zone_id: 3, initial_soul: 35 * @one_soul},
      %{name: "Voidreach Tavern", role: "TAVERN", zone_id: 4, initial_soul: 40 * @one_soul},
      %{name: "Voidreach Shop", role: "SHOP", zone_id: 4, initial_soul: 40 * @one_soul}
    ]
  end

  defp price_specs(item_ids, npc_ids) do
    base =
      [
        %{npc_key: {"Lumenveil Tavern", 1}, item_name: "Basic Health Potion", price: 1 * @one_soul},
        %{npc_key: {"Lumenveil Shop", 1}, item_name: "Iron Sword", price: 6 * @one_soul},
        %{npc_key: {"Lumenveil Smithy", 1}, item_name: "Leather Armor", price: 5 * @one_soul},
        %{npc_key: {"Graymarch Shop", 2}, item_name: "Iron Sword", price: 7 * @one_soul},
        %{npc_key: {"Graymarch Tavern", 2}, item_name: "Basic Health Potion", price: 2 * @one_soul},
        %{npc_key: {"Embervault Shop", 3}, item_name: "Fire Sword", price: 18 * @one_soul},
        %{npc_key: {"Embervault Tavern", 3}, item_name: "Basic Health Potion", price: 3 * @one_soul},
        %{npc_key: {"Voidreach Shop", 4}, item_name: "Steel Shield", price: 20 * @one_soul},
        %{npc_key: {"Voidreach Tavern", 4}, item_name: "Basic Health Potion", price: 4 * @one_soul}
      ]

    Enum.filter(base, fn %{npc_key: npc_key, item_name: item_name} ->
      Map.has_key?(npc_ids, npc_key) and Map.has_key?(item_ids, item_name)
    end)
  end
end
