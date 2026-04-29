defmodule AFW.Chain.Reader do
  @moduledoc "Stateless read-only chain access with per-call concurrency."

  alias AFW.Chain.{ABI, Cache, Contracts, Pool}
  alias Ethereumex.HttpClient

  @tracked_contracts [
    :afw_token,
    :soul_token,
    :world_map,
    :agent_registry,
    :node_registry,
    :oracle_gateway,
    :economy_engine,
    :quest_engine,
    :governance_dao,
    :item_registry,
    :monster_registry,
    :npc_registry,
    :event_treasury,
    :combat_resolver,
    :marketplace
  ]
  @task_timeout 30_000
  @zone_ttl 10_000
  @monster_ttl 5_000
  @npc_ttl 30_000
  @orders_ttl 5_000
  @treasury_ttl 5_000
  @item_lookup_ttl 60_000
  def tracked_contracts, do: @tracked_contracts

  def snapshot(agent_id) do
    agent = get_agent(agent_id)
    zone_id = agent["zoneId"]
    observer = agent["observer"]

    zone_task = Task.async(fn -> get_zone(zone_id) end)
    monsters_task = Task.async(fn -> get_monsters_in_zone(zone_id) end)
    npcs_task = Task.async(fn -> get_npcs_in_zone(zone_id) end)
    items_task = Task.async(fn -> get_agent_items(observer) end)
    orders_task = Task.async(fn -> active_orders() end)
    treasury_task = Task.async(fn -> get_treasury_balance() end)

    zone =
      safe_await(zone_task, %{
        "zoneId" => zone_id,
        "name" => "Unknown",
        "dangerLabel" => "UNKNOWN",
        "connections" => []
      })

    monsters = safe_await(monsters_task, [])
    npcs = safe_await(npcs_task, [])
    items = safe_await(items_task, [])
    orders = safe_await(orders_task, [])
    treasury_balance = safe_await(treasury_task, 0)

    %{
      agent: agent,
      zone: zone,
      monsters: monsters,
      npcs: npcs,
      items: items,
      orders: orders,
      treasury_balance: treasury_balance
    }
  end

  def get_agent(agent_id) do
    [agent_tuple] = call_contract(:agent_registry, "getAgent", [agent_id])

    {agent_key, observer, class_id, status_id, level, experience, zone_id, personality, stats, _,
     _, _} = agent_tuple

    %{
      "agentId" => agent_key,
      "observer" => encode_address(observer),
      "classId" => class_id,
      "className" => class_label(class_id),
      "statusId" => status_id,
      "statusName" => status_label(status_id),
      "level" => level,
      "experience" => experience,
      "zoneId" => zone_id,
      "personality" => parse_personality(personality),
      "stats" => parse_stats(stats)
    }
  end

  def get_zone(zone_id) do
    Cache.get_or_fetch({:zone, zone_id}, @zone_ttl, fn ->
      [zone_tuple] = call_contract(:world_map, "getZone", [zone_id])

      {zone_key, name, korean_name, danger_id, required_nodes, max_agents, unlocked, connections,
       unlocked_at} =
        zone_tuple

      %{
        "zoneId" => zone_key,
        "name" => name,
        "koreanName" => korean_name,
        "dangerId" => danger_id,
        "dangerLabel" => danger_label(danger_id),
        "requiredNodes" => required_nodes,
        "maxAgents" => max_agents,
        "isUnlocked" => unlocked,
        "connections" => connections,
        "unlockedAt" => unlocked_at
      }
    end)
  end

  def get_monsters_in_zone(zone_id) do
    Cache.get_or_fetch({:monsters, zone_id}, @monster_ttl, fn ->
      total = call_uint(:monster_registry, "totalMonsters", [])

      if total == 0 do
        []
      else
        1..total
        |> Task.async_stream(&monster_entry(&1, zone_id),
          timeout: @task_timeout,
          max_concurrency: 8,
          ordered: false
        )
        |> Enum.flat_map(fn
          {:ok, nil} -> []
          {:ok, entry} -> [entry]
          {:exit, _} -> []
        end)
        |> Enum.sort_by(& &1.monster_id)
      end
    end)
  rescue
    _ -> []
  end

  def get_alive_monsters_in_zone(zone_id) do
    total = call_uint(:monster_registry, "totalMonsters", [])

    if total == 0 do
      []
    else
      1..total
      |> Task.async_stream(&monster_entry(&1, zone_id),
        timeout: @task_timeout,
        max_concurrency: 8,
        ordered: false
      )
      |> Enum.flat_map(fn
        {:ok, nil} -> []
        {:ok, entry} -> [entry]
        {:exit, _} -> []
      end)
      |> Enum.sort_by(& &1.monster_id)
    end
  rescue
    _ -> []
  end

  def get_npcs_in_zone(zone_id) do
    Cache.get_or_fetch({:npcs, zone_id}, @npc_ttl, fn ->
      total = call_uint(:npc_registry, "totalNPCs", [])

      if total == 0 do
        []
      else
        1..total
        |> Task.async_stream(&npc_entry(&1, zone_id),
          timeout: @task_timeout,
          max_concurrency: 8,
          ordered: false
        )
        |> Enum.flat_map(fn
          {:ok, nil} -> []
          {:ok, entry} -> [entry]
          {:exit, _} -> []
        end)
        |> Enum.sort_by(& &1.npc_id)
      end
    end)
  rescue
    _ -> []
  end

  def get_agent_items(address) do
    total = call_uint(:item_registry, "totalItemTypes", [])
    owner = normalize_address(address || account_address())

    if total == 0 do
      []
    else
      1..total
      |> Task.async_stream(&item_entry(owner, &1),
        timeout: @task_timeout,
        max_concurrency: 8,
        ordered: false
      )
      |> Enum.flat_map(fn
        {:ok, nil} -> []
        {:ok, entry} -> [entry]
        {:exit, _} -> []
      end)
      |> Enum.sort_by(& &1.item_id)
    end
  rescue
    _ -> []
  end

  def active_orders do
    Cache.get_or_fetch(:orders, @orders_ttl, fn ->
      total = call_uint(:marketplace, "totalOrders", [])

      if total == 0 do
        []
      else
        1..total
        |> Task.async_stream(&order_entry/1,
          timeout: @task_timeout,
          max_concurrency: 8,
          ordered: false
        )
        |> Enum.flat_map(fn
          {:ok, nil} -> []
          {:ok, entry} -> [entry]
          {:exit, _} -> []
        end)
        |> Enum.sort_by(& &1.order_id)
      end
    end)
  rescue
    _ -> []
  end

  def get_active_orders do
    total = call_uint(:marketplace, "totalOrders", [])

    if total == 0 do
      []
    else
      1..total
      |> Task.async_stream(&order_entry/1,
        timeout: @task_timeout,
        max_concurrency: 8,
        ordered: false
      )
      |> Enum.flat_map(fn
        {:ok, nil} -> []
        {:ok, entry} -> [entry]
        {:exit, _} -> []
      end)
      |> Enum.sort_by(& &1.order_id)
    end
  rescue
    _ -> []
  end

  def get_agent_fresh_state(agent_id), do: get_agent(agent_id)

  def get_monster_fresh(monster_id) do
    [monster_tuple] = call_contract(:monster_registry, "getMonster", [monster_id])
    {type_id, hp, atk, def_value, soul_balance, zone_id, alive} = monster_tuple
    [type_tuple] = call_contract(:monster_registry, "getMonsterType", [type_id])
    {name, danger_level, _, _, _, _, _, _, _, _, _, _} = type_tuple

    %{
      monster_id: monster_id,
      type_id: type_id,
      name: name,
      atk: atk,
      def: def_value,
      hp: hp,
      soul_balance: soul_balance,
      zone_id: zone_id,
      danger_level: danger_level,
      alive: alive
    }
  rescue
    _ -> nil
  end

  def get_npc_fresh(npc_id) do
    [type_id, soul_balance, zone_id, active] = call_contract(:npc_registry, "npcs", [npc_id])
    [name, role, _, _, _] = call_contract(:npc_registry, "npcTypes", [type_id])

    %{
      npc_id: npc_id,
      name: name,
      role: role,
      zone_id: zone_id,
      soul_balance: soul_balance,
      active: active
    }
  rescue
    _ -> nil
  end

  def get_soul_balance(address) do
    call_uint(:soul_token, "balanceOf", [normalize_address(address || account_address())])
  rescue
    _ -> 0
  end

  def get_npc_price(npc_id, item_id) do
    case call_contract(:npc_registry, "npcPrices", [npc_id, item_id]) do
      [entry] -> parse_npc_price(entry, item_id)
      [item_key, price, available] -> %{item_id: item_key, price: price, available: available}
      _ -> %{item_id: item_id, price: 0, available: false}
    end
  rescue
    _ -> %{item_id: item_id, price: 0, available: false}
  end

  def find_item_type_id(name) do
    Cache.get_or_fetch({:item_type_id, name}, @item_lookup_ttl, fn ->
      total = call_uint(:item_registry, "totalItemTypes", [])

      Enum.find_value(1..total, fn item_id ->
        case call_contract(:item_registry, "itemTypes", [item_id]) do
          [^name, _, _, _, _, _, _] -> item_id
          _ -> nil
        end
      end)
    end)
  rescue
    _ -> nil
  end

  def get_treasury_balance do
    Cache.get_or_fetch(:treasury, @treasury_ttl, fn ->
      call_uint(:event_treasury, "balance", [])
    end)
  rescue
    _ -> 0
  end

  def soul_metrics do
    tasks = [
      Task.async(fn -> call_uint(:soul_token, "totalMinted", []) end),
      Task.async(fn -> call_uint(:soul_token, "totalBurned", []) end),
      Task.async(fn -> call_uint(:soul_token, "totalSupply", []) end)
    ]

    [total_minted, total_burned, total_supply] = Task.await_many(tasks, @task_timeout)

    %{
      total_minted: total_minted,
      total_burned: total_burned,
      total_supply: total_supply
    }
  end

  def get_node_stats do
    total = call_uint(:node_registry, "getActiveNodeCount", [])

    if total == 0 do
      []
    else
      0..(total - 1)
      |> Enum.map(fn index ->
        address =
          call_contract(:node_registry, "activeNodes", [index])
          |> List.first()
          |> encode_address()

        [
          operator,
          tier,
          _spec,
          _staked,
          _registered_at,
          _uptime_blocks,
          pending_reward,
          _total_slashings,
          active,
          endpoint
        ] =
          call_contract(:node_registry, "nodes", [address])

        %{
          address: encode_address(operator),
          tier: tier,
          pending_reward: pending_reward,
          uptime_pct: 100,
          quality: 100,
          inference_count: max(pending_reward |> div(1_000_000_000_000_000_000), 1),
          active: active,
          endpoint: endpoint
        }
      end)
    end
  rescue
    _ -> []
  end

  def get_creator_stats do
    monster_total = call_uint(:monster_registry, "totalMonsterTypes", [])
    quest_total = call_uint(:quest_engine, "totalQuests", [])

    monster_creators =
      Enum.map(1..monster_total, fn type_id ->
        [
          _name,
          _danger,
          _min_hp,
          _max_hp,
          _min_atk,
          _max_atk,
          _min_def,
          _max_def,
          _min_soul,
          _max_soul,
          creator,
          active
        ] =
          call_contract(:monster_registry, "monsterTypes", [type_id])

        %{address: encode_address(creator), content_uses: if(active, do: 20, else: 0)}
      end)

    quest_creators =
      Enum.map(1..quest_total, fn quest_id ->
        [
          _quest_id,
          _name,
          _description,
          _zone_id,
          _difficulty,
          _condition,
          reward,
          creator,
          _bps,
          active,
          _created_at
        ] =
          call_contract(:quest_engine, "quests", [quest_id])

        soul_amount =
          case reward do
            {amount, _, _, _} -> amount
            _ -> 0
          end

        %{
          address: encode_address(creator),
          content_uses: if(active, do: max(div(soul_amount, 10 ** 18), 1), else: 0)
        }
      end)

    (monster_creators ++ quest_creators)
    |> Enum.group_by(& &1.address)
    |> Enum.map(fn {address, rows} ->
      %{
        address: address,
        content_uses: Enum.reduce(rows, 0, fn row, acc -> acc + row.content_uses end)
      }
    end)
  rescue
    _ -> []
  end

  def account_address do
    private_key = Application.fetch_env!(:afw, :private_key)
    derive_address!(decode_hex_key!(private_key))
  end

  def rpc_url, do: Application.fetch_env!(:afw, :rpc_url)

  def call_contract(contract_key, function_name, args) do
    {:ok, data} = ABI.encode(function_name, args, abi_name(contract_key))

    tx = %{
      "to" => normalize_address(Contracts.get(contract_key)),
      "data" => data
    }

    case Pool.request(fn url -> HttpClient.eth_call(tx, "latest", url: url) end) do
      {:ok, result} ->
        ABI.decode_call_result(function_name, result, abi_name(contract_key), length(args))

      {:error, reason} ->
        raise "eth_call failed for #{contract_key}.#{function_name}: #{inspect(reason)}"
    end
  end

  def call_uint(contract_key, function_name, args) do
    case call_contract(contract_key, function_name, args) do
      [value] when is_integer(value) -> value
      value when is_integer(value) -> value
      [value] -> normalize_integer(value)
      value -> normalize_integer(value)
    end
  end

  def call_bool(contract_key, function_name, args) do
    case call_contract(contract_key, function_name, args) do
      [value] when is_boolean(value) -> value
      value when is_boolean(value) -> value
      [value] -> !!value
      value -> !!value
    end
  end

  defp monster_entry(monster_id, zone_id) do
    [monster_tuple] = call_contract(:monster_registry, "getMonster", [monster_id])
    {type_id, hp, atk, def_value, soul_balance, monster_zone_id, alive} = monster_tuple

    if monster_zone_id != zone_id or not alive do
      nil
    else
      [type_tuple] = call_contract(:monster_registry, "getMonsterType", [type_id])
      {name, danger_level, _, _, _, _, _, _, _, _, _, _} = type_tuple

      %{
        monster_id: monster_id,
        name: name,
        atk: atk,
        def: def_value,
        hp: hp,
        soul_balance: soul_balance,
        zone_id: monster_zone_id,
        danger_level: danger_level
      }
    end
  end

  defp npc_entry(npc_id, zone_id) do
    [type_id, soul_balance, npc_zone_id, active] = call_contract(:npc_registry, "npcs", [npc_id])

    if npc_zone_id != zone_id or not active do
      nil
    else
      [name, role, _, _, _] = call_contract(:npc_registry, "npcTypes", [type_id])

      %{
        npc_id: npc_id,
        name: name,
        role: role,
        zone_id: npc_zone_id,
        soul_balance: soul_balance
      }
    end
  end

  defp item_entry(owner, item_id) do
    balance = call_uint(:item_registry, "balanceOf", [owner, item_id])

    if balance > 0 do
      [name, category, tier, min_stat, max_stat, creator, tradeable] =
        call_contract(:item_registry, "itemTypes", [item_id])

      %{
        item_id: item_id,
        name: name,
        category: category,
        tier: tier,
        min_stat: min_stat,
        max_stat: max_stat,
        creator: encode_address(creator),
        tradeable: tradeable,
        balance: balance
      }
    end
  end

  defp order_entry(order_id) do
    [seller, item_id, amount, price_in_soul, active, _created_at] =
      call_contract(:marketplace, "orders", [order_id])

    if active do
      %{
        order_id: order_id,
        item_id: item_id,
        amount: amount,
        price_in_soul: price_in_soul,
        seller: encode_address(seller)
      }
    end
  end

  defp class_label(class_id) do
    case call_contract(:agent_registry, "classRegistry", [class_id]) do
      [_, name, _, _, true] -> name
      _ -> "Class #{class_id}"
    end
  rescue
    _ -> "Class #{class_id}"
  end

  defp status_label(status_id) do
    case call_contract(:agent_registry, "statusRegistry", [status_id]) do
      [_, name, _, true] -> name
      _ -> "STATUS_#{status_id}"
    end
  rescue
    _ -> "STATUS_#{status_id}"
  end

  defp danger_label(danger_id) do
    case call_contract(:world_map, "dangerLevels", [danger_id]) do
      [_, name, _, _, true] -> name
      _ -> "DANGER_#{danger_id}"
    end
  rescue
    _ -> "DANGER_#{danger_id}"
  end

  defp parse_personality({bravery, greed, sociability, curiosity, loyalty}) do
    %{
      "bravery" => bravery,
      "greed" => greed,
      "sociability" => sociability,
      "curiosity" => curiosity,
      "loyalty" => loyalty
    }
  end

  defp parse_stats({hp, max_hp, mp, max_mp, attack, defense, speed}) do
    %{
      "hp" => hp,
      "maxHp" => max_hp,
      "mp" => mp,
      "maxMp" => max_mp,
      "attack" => attack,
      "defense" => defense,
      "speed" => speed
    }
  end

  defp parse_npc_price({item_id, price, available}, _fallback_item_id) do
    %{item_id: item_id, price: price, available: available}
  end

  defp parse_npc_price([item_id, price, available], _fallback_item_id) do
    %{item_id: item_id, price: price, available: available}
  end

  defp parse_npc_price(_, fallback_item_id) do
    %{item_id: fallback_item_id, price: 0, available: false}
  end

  defp decode_hex_key!("0x" <> hex), do: Base.decode16!(hex, case: :mixed)
  defp decode_hex_key!(hex), do: Base.decode16!(hex, case: :mixed)

  defp derive_address!(private_key) do
    {:ok, public_key} = ExSecp256k1.create_public_key(private_key)

    encoded_key =
      case public_key do
        <<4, rest::binary-size(64)>> -> rest
        <<_::binary-size(64)>> = raw -> raw
        other -> raise "Unexpected public key shape: #{byte_size(other)} bytes"
      end

    <<_::binary-size(12), address::binary-size(20)>> = ExKeccak.hash_256(encoded_key)
    encode_address(address)
  end

  defp encode_address(address) when is_binary(address) and byte_size(address) == 20 do
    "0x" <> Base.encode16(address, case: :lower)
  end

  defp encode_address("0x" <> _ = address), do: String.downcase(address)

  defp normalize_address("0x" <> _ = address), do: String.downcase(address)
  defp normalize_address(address), do: "0x" <> String.downcase(address)

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer("0x"), do: 0
  defp normalize_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp normalize_integer(value), do: value

  defp abi_name(contract_key) do
    contract_key
    |> Atom.to_string()
    |> Macro.camelize()
  end

  defp safe_await(task, fallback) do
    Task.await(task, @task_timeout)
  catch
    :exit, _ ->
      Task.shutdown(task, :brutal_kill)
      fallback
  end
end
