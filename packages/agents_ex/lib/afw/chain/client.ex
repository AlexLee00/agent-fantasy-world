defmodule AFW.Chain.Client do
  @moduledoc "Shared JSON-RPC client GenServer for the 15 deployed AFW contracts."
  use GenServer

  alias AFW.Chain.{ABI, Contracts, RLP}
  alias Ethereumex.HttpClient

  @chain_id 84_532
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
  @max_receipt_polls 30
  @receipt_poll_ms 2_000
  @gas_padding_bps 1_200
  @approval_padding 10 * 1_000_000_000_000_000_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def snapshot(agent_id), do: GenServer.call(__MODULE__, {:snapshot, agent_id}, 60_000)

  def create_agent(class_id, personality),
    do: GenServer.call(__MODULE__, {:create_agent, class_id, personality}, 120_000)

  def resolve_combat(agent_id, monster_id),
    do: GenServer.call(__MODULE__, {:resolve_combat, agent_id, monster_id}, 120_000)

  def buy_from_npc(npc_id, item_id),
    do: GenServer.call(__MODULE__, {:buy_from_npc, npc_id, item_id}, 120_000)

  def create_market_order(item_id, amount, price),
    do: GenServer.call(__MODULE__, {:create_market_order, item_id, amount, price}, 120_000)

  def fill_market_order(order_id),
    do: GenServer.call(__MODULE__, {:fill_market_order, order_id}, 120_000)

  def register_item_type(name, category, tier, min_stat, max_stat, tradeable) do
    GenServer.call(
      __MODULE__,
      {:register_item_type, name, category, tier, min_stat, max_stat, tradeable},
      120_000
    )
  end

  def register_monster_type(attrs),
    do: GenServer.call(__MODULE__, {:register_monster_type, attrs}, 120_000)

  def spawn_monster(type_id, zone_id),
    do: GenServer.call(__MODULE__, {:spawn_monster, type_id, zone_id}, 120_000)

  def register_npc_type(name, role, zone_id),
    do: GenServer.call(__MODULE__, {:register_npc_type, name, role, zone_id}, 120_000)

  def spawn_npc(type_id, zone_id, initial_soul),
    do: GenServer.call(__MODULE__, {:spawn_npc, type_id, zone_id, initial_soul}, 120_000)

  def set_npc_price(npc_id, item_id, price),
    do: GenServer.call(__MODULE__, {:set_npc_price, npc_id, item_id, price}, 120_000)

  def get_treasury_balance, do: GenServer.call(__MODULE__, :get_treasury_balance, 60_000)
  def get_agent(agent_id), do: GenServer.call(__MODULE__, {:get_agent, agent_id}, 60_000)
  def get_zone(zone_id), do: GenServer.call(__MODULE__, {:get_zone, zone_id}, 60_000)
  def get_monsters_in_zone(zone_id), do: GenServer.call(__MODULE__, {:get_monsters_in_zone, zone_id}, 60_000)
  def get_npcs_in_zone(zone_id), do: GenServer.call(__MODULE__, {:get_npcs_in_zone, zone_id}, 60_000)
  def get_agent_items(address), do: GenServer.call(__MODULE__, {:get_agent_items, address}, 60_000)
  def active_orders, do: GenServer.call(__MODULE__, :active_orders, 60_000)
  def soul_metrics, do: GenServer.call(__MODULE__, :soul_metrics, 60_000)
  def tracked_contracts, do: @tracked_contracts
  def account_address, do: GenServer.call(__MODULE__, :account_address)

  @impl true
  def init(opts) do
    private_key_hex = Keyword.get(opts, :private_key) || Application.fetch_env!(:afw, :private_key)
    private_key = decode_hex_key!(private_key_hex)
    address = derive_address!(private_key)

    state = %{
      rpc_url: Keyword.get(opts, :rpc_url) || Application.fetch_env!(:afw, :rpc_url),
      private_key: private_key,
      account_address: address,
      contracts: Contracts.all(),
      latest_agent_id: 0,
      next_nonce: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:account_address, _from, state) do
    {:reply, state.account_address, state}
  end

  def handle_call({:snapshot, agent_id}, _from, state) do
    agent = get_agent(agent_id, state)
    zone = get_zone(agent["zoneId"], state)

    reply = %{
      agent: agent,
      zone: zone,
      monsters: get_monsters_in_zone_internal(zone["zoneId"], state),
      npcs: get_npcs_in_zone_internal(zone["zoneId"], state),
      items: get_agent_items_internal(agent["observer"], state),
      orders: active_orders_internal(state),
      treasury_balance: treasury_balance(state)
    }

    {:reply, reply, state}
  end

  def handle_call({:create_agent, class_id, personality}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        total_before = call_uint(:agent_registry, "totalAgents", [], state)

        {tx, next_state} =
          submit_contract_transaction(
            :agent_registry,
            "createAgent",
            [normalize_class_id(class_id), normalize_personality(personality)],
            state
          )

        total_after = call_uint(:agent_registry, "totalAgents", [], next_state)
        agent_id = max(total_after, total_before + 1)

        payload =
          tx
          |> Map.put(:agent_id, agent_id)
          |> Map.put(:result, total_after)

        {payload, %{next_state | latest_agent_id: agent_id}}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:resolve_combat, agent_id, monster_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        submit_contract_transaction(:combat_resolver, "resolveCombat", [agent_id, monster_id], state)
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:buy_from_npc, npc_id, item_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        price = get_npc_price(npc_id, item_id, state)
        {_, state} = ensure_soul_allowance(:npc_registry, price.price, state)
        {tx, next_state} = submit_contract_transaction(:npc_registry, "buyFromNPC", [npc_id, item_id], state)
        {Map.put(tx, :price, price.price), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:create_market_order, item_id, amount, price}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        {_, state} = ensure_item_approval(:marketplace, state)
        {tx, next_state} =
          submit_contract_transaction(:marketplace, "createOrder", [item_id, amount, price], state)

        order_id = call_uint(:marketplace, "totalOrders", [], next_state)
        {Map.put(tx, :order_id, order_id), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:fill_market_order, order_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        order = get_order(order_id, state)
        {_, state} = ensure_soul_allowance(:marketplace, order.price_in_soul, state)
        submit_contract_transaction(:marketplace, "fillOrder", [order_id], state)
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:register_item_type, name, category, tier, min_stat, max_stat, tradeable}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        {tx, next_state} =
          submit_contract_transaction(
            :item_registry,
            "registerItemType",
            [name, category, tier, min_stat, max_stat, tradeable],
            state
          )

        item_id = call_uint(:item_registry, "totalItemTypes", [], next_state)
        {Map.put(tx, :item_id, item_id), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:register_monster_type, attrs}, _from, state) do
    args = [
      attrs.name,
      attrs.danger_level,
      attrs.min_hp,
      attrs.max_hp,
      attrs.min_atk,
      attrs.max_atk,
      attrs.min_def,
      attrs.max_def,
      attrs.min_soul,
      attrs.max_soul
    ]

    {reply, next_state} =
      attempt_write(state, fn state ->
        {tx, next_state} =
          submit_contract_transaction(:monster_registry, "registerMonsterType", args, state)

        type_id = call_uint(:monster_registry, "totalMonsterTypes", [], next_state)
        {Map.put(tx, :type_id, type_id), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:spawn_monster, type_id, zone_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        {tx, next_state} =
          submit_contract_transaction(:monster_registry, "spawnMonster", [type_id, zone_id], state)

        monster_id = call_uint(:monster_registry, "totalMonsters", [], next_state)
        {Map.put(tx, :monster_id, monster_id), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:register_npc_type, name, role, zone_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        {tx, next_state} =
          submit_contract_transaction(:npc_registry, "registerNPCType", [name, role, zone_id], state)

        type_id = call_uint(:npc_registry, "totalNPCTypes", [], next_state)
        {Map.put(tx, :type_id, type_id), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:spawn_npc, type_id, zone_id, initial_soul}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        {tx, next_state} =
          submit_contract_transaction(:npc_registry, "spawnNPC", [type_id, zone_id, initial_soul], state)

        npc_id = call_uint(:npc_registry, "totalNPCs", [], next_state)
        {Map.put(tx, :npc_id, npc_id), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:set_npc_price, npc_id, item_id, price}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        submit_contract_transaction(:npc_registry, "setPrice", [npc_id, item_id, price], state)
      end)

    {:reply, reply, next_state}
  end

  def handle_call(:get_treasury_balance, _from, state) do
    {:reply, treasury_balance(state), state}
  end

  def handle_call({:get_agent, agent_id}, _from, state) do
    {:reply, get_agent(agent_id, state), state}
  end

  def handle_call({:get_zone, zone_id}, _from, state) do
    {:reply, get_zone(zone_id, state), state}
  end

  def handle_call({:get_monsters_in_zone, zone_id}, _from, state) do
    {:reply, get_monsters_in_zone_internal(zone_id, state), state}
  end

  def handle_call({:get_npcs_in_zone, zone_id}, _from, state) do
    {:reply, get_npcs_in_zone_internal(zone_id, state), state}
  end

  def handle_call({:get_agent_items, address}, _from, state) do
    {:reply, get_agent_items_internal(address, state), state}
  end

  def handle_call(:active_orders, _from, state) do
    {:reply, active_orders_internal(state), state}
  end

  def handle_call(:soul_metrics, _from, state) do
    reply = %{
      total_minted: call_uint(:soul_token, "totalMinted", [], state),
      total_burned: call_uint(:soul_token, "totalBurned", [], state),
      total_supply: call_uint(:soul_token, "totalSupply", [], state)
    }

    {:reply, reply, state}
  end

  defp get_agent(agent_id, state) do
    [agent_tuple] = call_contract(:agent_registry, "getAgent", [agent_id], state)
    {agent_key, observer, class_id, status_id, level, experience, zone_id, personality, stats, _, _, _} = agent_tuple

    %{
      "agentId" => agent_key,
      "observer" => encode_address(observer),
      "classId" => class_id,
      "className" => class_label(class_id, state),
      "statusId" => status_id,
      "statusName" => status_label(status_id, state),
      "level" => level,
      "experience" => experience,
      "zoneId" => zone_id,
      "personality" => parse_personality(personality),
      "stats" => parse_stats(stats)
    }
  end

  defp get_zone(zone_id, state) do
    [zone_tuple] = call_contract(:world_map, "getZone", [zone_id], state)
    {zone_key, name, korean_name, danger_id, required_nodes, max_agents, unlocked, connections, unlocked_at} =
      zone_tuple

    %{
      "zoneId" => zone_key,
      "name" => name,
      "koreanName" => korean_name,
      "dangerId" => danger_id,
      "dangerLabel" => danger_label(danger_id, state),
      "requiredNodes" => required_nodes,
      "maxAgents" => max_agents,
      "isUnlocked" => unlocked,
      "connections" => connections,
      "unlockedAt" => unlocked_at
    }
  end

  defp get_monsters_in_zone_internal(zone_id, state) do
    total = call_uint(:monster_registry, "totalMonsters", [], state)

    if total == 0 do
      []
    else
      for monster_id <- 1..total,
          monster = get_monster(monster_id, state),
          monster.zone_id == zone_id,
          monster.alive do
        type = get_monster_type(monster.type_id, state)

        %{
          monster_id: monster_id,
          name: type.name,
          atk: monster.atk,
          def: monster.def,
          hp: monster.hp,
          soul_balance: monster.soul_balance,
          zone_id: monster.zone_id,
          danger_level: type.danger_level
        }
      end
    end
  rescue
    _ -> []
  end

  defp get_npcs_in_zone_internal(zone_id, state) do
    total = call_uint(:npc_registry, "totalNPCs", [], state)

    if total == 0 do
      []
    else
      for npc_id <- 1..total,
          npc = get_npc(npc_id, state),
          npc.zone_id == zone_id,
          npc.active do
        type = get_npc_type(npc.type_id, state)

        %{
          npc_id: npc_id,
          name: type.name,
          role: type.role,
          zone_id: npc.zone_id,
          soul_balance: npc.soul_balance
        }
      end
    end
  rescue
    _ -> []
  end

  defp get_agent_items_internal(address, state) do
    total = call_uint(:item_registry, "totalItemTypes", [], state)
    owner = normalize_address(address || state.account_address)

    if total == 0 do
      []
    else
      for item_id <- 1..total,
          balance = call_uint(:item_registry, "balanceOf", [owner, item_id], state),
          balance > 0 do
        [name, category, tier, min_stat, max_stat, creator, tradeable] =
          call_contract(:item_registry, "itemTypes", [item_id], state)

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
  rescue
    _ -> []
  end

  defp active_orders_internal(state) do
    total = call_uint(:marketplace, "totalOrders", [], state)

    if total == 0 do
      []
    else
      for order_id <- 1..total,
          order = get_order(order_id, state),
          order.active do
        %{
          order_id: order_id,
          item_id: order.item_id,
          amount: order.amount,
          price_in_soul: order.price_in_soul,
          seller: order.seller
        }
      end
    end
  rescue
    _ -> []
  end

  defp treasury_balance(state) do
    call_uint(:event_treasury, "balance", [], state)
  rescue
    _ -> 0
  end

  defp get_monster(monster_id, state) do
    [monster_tuple] = call_contract(:monster_registry, "getMonster", [monster_id], state)
    {type_id, hp, atk, def_value, soul_balance, zone_id, alive} = monster_tuple

    %{
      type_id: type_id,
      hp: hp,
      atk: atk,
      def: def_value,
      soul_balance: soul_balance,
      zone_id: zone_id,
      alive: alive
    }
  end

  defp get_monster_type(type_id, state) do
    [monster_type] = call_contract(:monster_registry, "getMonsterType", [type_id], state)
    {name, danger_level, min_hp, max_hp, min_atk, max_atk, min_def, max_def, min_soul, max_soul, creator, active} =
      monster_type

    %{
      name: name,
      danger_level: danger_level,
      min_hp: min_hp,
      max_hp: max_hp,
      min_atk: min_atk,
      max_atk: max_atk,
      min_def: min_def,
      max_def: max_def,
      min_soul: min_soul,
      max_soul: max_soul,
      creator: encode_address(creator),
      active: active
    }
  end

  defp get_npc(npc_id, state) do
    [type_id, soul_balance, zone_id, active] = call_contract(:npc_registry, "npcs", [npc_id], state)
    %{type_id: type_id, soul_balance: soul_balance, zone_id: zone_id, active: active}
  end

  defp get_npc_type(type_id, state) do
    [name, role, zone_id, creator, active] = call_contract(:npc_registry, "npcTypes", [type_id], state)
    %{name: name, role: role, zone_id: zone_id, creator: encode_address(creator), active: active}
  end

  defp get_npc_price(npc_id, item_id, state) do
    [item_key, price, available] = call_contract(:npc_registry, "npcPrices", [npc_id, item_id], state)
    %{item_id: item_key, price: price, available: available}
  end

  defp get_order(order_id, state) do
    [seller, item_id, amount, price_in_soul, active, created_at] =
      call_contract(:marketplace, "orders", [order_id], state)

    %{
      seller: encode_address(seller),
      item_id: item_id,
      amount: amount,
      price_in_soul: price_in_soul,
      active: active,
      created_at: created_at
    }
  end

  defp class_label(class_id, state) do
    case call_contract(:agent_registry, "classRegistry", [class_id], state) do
      [_, name, _, _, true] -> name
      _ -> "Class #{class_id}"
    end
  rescue
    _ -> "Class #{class_id}"
  end

  defp status_label(status_id, state) do
    case call_contract(:agent_registry, "statusRegistry", [status_id], state) do
      [_, name, _, true] -> name
      _ -> "STATUS_#{status_id}"
    end
  rescue
    _ -> "STATUS_#{status_id}"
  end

  defp danger_label(danger_id, state) do
    case call_contract(:world_map, "dangerLevels", [danger_id], state) do
      [_, name, _, _, true] -> name
      _ -> "DANGER_#{danger_id}"
    end
  rescue
    _ -> "DANGER_#{danger_id}"
  end

  defp ensure_soul_allowance(spender_key, required_amount, state) do
    spender = state.contracts[spender_key]
    allowance = call_uint(:soul_token, "allowance", [state.account_address, spender], state)

    if allowance >= required_amount do
      {%{status: :already_approved, spender: spender, allowance: allowance}, state}
    else
      amount = required_amount + @approval_padding
      submit_contract_transaction(:soul_token, "approve", [spender, amount], state)
    end
  end

  defp ensure_item_approval(operator_key, state) do
    operator = state.contracts[operator_key]
    approved = call_bool(:item_registry, "isApprovedForAll", [state.account_address, operator], state)

    if approved do
      {%{status: :already_approved, operator: operator}, state}
    else
      submit_contract_transaction(:item_registry, "setApprovalForAll", [operator, true], state)
    end
  end

  defp submit_contract_transaction(contract_key, function_name, args, state) do
    {:ok, data} = ABI.encode(function_name, args, abi_name(contract_key))
    nonce = next_nonce(state)
    chain_id = fetch_chain_id(state)
    max_priority_fee = fetch_max_priority_fee(state)
    max_fee = fetch_max_fee(state, max_priority_fee)
    to = normalize_address(state.contracts[contract_key])

    gas_limit =
      estimate_gas(
        %{
          "from" => state.account_address,
          "to" => to,
          "data" => data,
          "value" => quantity(0)
        },
        state
      )

    raw_tx =
      build_and_sign_eip1559_tx(
        chain_id,
        nonce,
        max_priority_fee,
        max_fee,
        gas_limit,
        to,
        0,
        ABI.decode_hex!(data),
        state.private_key
      )

    case HttpClient.eth_send_raw_transaction("0x" <> Base.encode16(raw_tx, case: :lower), rpc_opts(state)) do
      {:ok, tx_hash} ->
        receipt = wait_for_receipt!(tx_hash, state)

        if quantity_to_integer(Map.get(receipt, "status", "0x1")) != 1 do
          raise "Transaction #{tx_hash} reverted"
        end

        payload = %{
          contract: contract_key,
          function: function_name,
          args: args,
          address: to,
          tx_hash: tx_hash,
          receipt: receipt
        }

        {payload, %{state | next_nonce: nonce + 1}}

      {:error, reason} ->
        raise "eth_sendRawTransaction failed for #{function_name}: #{inspect(reason)}"
    end
  end

  defp call_contract(contract_key, function_name, args, state) do
    {:ok, data} = ABI.encode(function_name, args, abi_name(contract_key))

    tx = %{
      "to" => normalize_address(state.contracts[contract_key]),
      "data" => data
    }

    case HttpClient.eth_call(tx, "latest", rpc_opts(state)) do
      {:ok, result} ->
        ABI.decode_call_result(function_name, result, abi_name(contract_key), length(args))

      {:error, reason} ->
        raise "eth_call failed for #{contract_key}.#{function_name}: #{inspect(reason)}"
    end
  end

  defp call_uint(contract_key, function_name, args, state) do
    case call_contract(contract_key, function_name, args, state) do
      [value] when is_integer(value) -> value
      value when is_integer(value) -> value
      [value] -> normalize_integer(value)
      value -> normalize_integer(value)
    end
  end

  defp call_bool(contract_key, function_name, args, state) do
    case call_contract(contract_key, function_name, args, state) do
      [value] when is_boolean(value) -> value
      value when is_boolean(value) -> value
      [value] -> !!value
      value -> !!value
    end
  end

  defp next_nonce(state) do
    case state.next_nonce do
      nil ->
        case HttpClient.eth_get_transaction_count(state.account_address, "pending", rpc_opts(state)) do
          {:ok, quantity_hex} -> quantity_to_integer(quantity_hex)
          {:error, reason} -> raise "Unable to fetch nonce: #{inspect(reason)}"
        end

      nonce ->
        nonce
    end
  end

  defp fetch_chain_id(state) do
    case HttpClient.eth_chain_id(rpc_opts(state)) do
      {:ok, quantity_hex} -> quantity_to_integer(quantity_hex)
      {:error, _} -> @chain_id
    end
  end

  defp fetch_max_priority_fee(state) do
    case HttpClient.eth_max_priority_fee_per_gas(rpc_opts(state)) do
      {:ok, quantity_hex} -> quantity_to_integer(quantity_hex)
      {:error, _} -> 100_000_000
    end
  end

  defp fetch_max_fee(state, max_priority_fee) do
    case HttpClient.eth_fee_history("0x1", "latest", [50], rpc_opts(state)) do
      {:ok, %{"baseFeePerGas" => [base_fee_hex | _]}} ->
        base_fee = quantity_to_integer(base_fee_hex)
        base_fee * 2 + max_priority_fee

      {:error, _} ->
        max_priority_fee * 2
    end
  end

  defp estimate_gas(tx, state) do
    case HttpClient.eth_estimate_gas(tx, rpc_opts(state)) do
      {:ok, quantity_hex} ->
        quantity_to_integer(quantity_hex)
        |> Kernel.*(@gas_padding_bps)
        |> div(1_000)

      {:error, reason} ->
        raise "eth_estimateGas failed: #{inspect(reason)}"
    end
  end

  defp wait_for_receipt!(tx_hash, state, attempts \\ @max_receipt_polls)

  defp wait_for_receipt!(tx_hash, state, attempts) when attempts > 0 do
    case HttpClient.eth_get_transaction_receipt(tx_hash, rpc_opts(state)) do
      {:ok, nil} ->
        Process.sleep(@receipt_poll_ms)
        wait_for_receipt!(tx_hash, state, attempts - 1)

      {:ok, receipt} ->
        receipt

      {:error, reason} ->
        raise "eth_getTransactionReceipt failed for #{tx_hash}: #{inspect(reason)}"
    end
  end

  defp wait_for_receipt!(tx_hash, _state, 0) do
    raise "Timed out waiting for receipt #{tx_hash}"
  end

  defp build_and_sign_eip1559_tx(chain_id, nonce, max_priority_fee, max_fee, gas_limit, to, value, data, private_key) do
    unsigned_fields = [
      chain_id,
      nonce,
      max_priority_fee,
      max_fee,
      gas_limit,
      ABI.decode_hex!(to),
      value,
      data,
      []
    ]

    signing_payload = <<0x02>> <> RLP.encode(unsigned_fields)
    digest = ExKeccak.hash_256(signing_payload)

    {:ok, {signature, recovery_id}} = ExSecp256k1.sign_compact(digest, private_key)
    <<r::binary-size(32), s::binary-size(32)>> = signature

    signed_fields = unsigned_fields ++ [recovery_id, :binary.decode_unsigned(r), :binary.decode_unsigned(s)]
    <<0x02>> <> RLP.encode(signed_fields)
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

  defp normalize_class_id(0), do: 1
  defp normalize_class_id(class_id), do: class_id

  defp normalize_personality(list) when is_list(list) and length(list) == 5 do
    Enum.map(list, &normalize_integer/1)
  end

  defp normalize_address("0x" <> _ = address), do: String.downcase(address)
  defp normalize_address(address), do: "0x" <> String.downcase(address)

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer(value) when is_binary(value), do: quantity_to_integer(value)

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

  defp quantity(value), do: "0x" <> Integer.to_string(value, 16)

  defp quantity_to_integer("0x"), do: 0
  defp quantity_to_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp quantity_to_integer(value) when is_integer(value), do: value

  defp abi_name(contract_key) do
    contract_key
    |> Atom.to_string()
    |> Macro.camelize()
  end

  defp rpc_opts(state), do: [url: state.rpc_url]

  defp attempt_write(state, fun) do
    try do
      {payload, next_state} = fun.(state)
      {{:ok, payload}, next_state}
    rescue
      error ->
        {{:error, Exception.message(error)}, %{state | next_nonce: nil}}
    end
  end
end
