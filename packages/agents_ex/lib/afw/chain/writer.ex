defmodule AFW.Chain.Writer do
  @moduledoc "Single-process write path that owns nonce management and raw transaction signing."
  use GenServer
  require Logger

  alias AFW.Chain.{ABI, Cache, Contracts, Pool, RLP, Reader}
  alias Ethereumex.HttpClient

  @chain_id 84_532
  @max_receipt_polls 20
  @receipt_poll_steps [300, 500, 750, 1_000, 1_250, 1_500]
  @gas_padding_bps 1_200
  @approval_padding 10 * 1_000_000_000_000_000_000
  @gas_cache_ttl_ms 60_000
  @estimate_retry_count 3
  @estimate_retry_sleep_ms 1_000
  @combat_fallback_gas_limit 500_000
  @npc_fallback_gas_limit 200_000
  @market_fallback_gas_limit 300_000
  @agent_fallback_gas_limit 200_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def account_address, do: GenServer.call(__MODULE__, :account_address)

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

  def update_agent_state(agent_id, stats, exp_gained, zone_id, status_id),
    do: GenServer.call(__MODULE__, {:update_agent_state, agent_id, stats, exp_gained, zone_id, status_id}, 120_000)
  def distribute_node_rewards(addresses, amounts, epoch),
    do: GenServer.call(__MODULE__, {:distribute_node_rewards, addresses, amounts, epoch}, 120_000)
  def distribute_bounty_rewards(addresses, amounts, epoch),
    do: GenServer.call(__MODULE__, {:distribute_bounty_rewards, addresses, amounts, epoch}, 120_000)
  def propose_governance_action(proposal_type, title, description, target, call_data),
    do: GenServer.call(__MODULE__, {:propose_governance_action, proposal_type, title, description, target, call_data}, 120_000)
  def trigger_event_treasury_check,
    do: GenServer.call(__MODULE__, :trigger_event_treasury_check, 120_000)

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

  @impl true
  def init(opts) do
    private_key_hex = Keyword.get(opts, :private_key) || Application.fetch_env!(:afw, :private_key)
    private_key = decode_hex_key!(private_key_hex)
    account_address = Reader.account_address()

    state = %{
      rpc_url: Keyword.get(opts, :rpc_url) || Application.fetch_env!(:afw, :rpc_url),
      private_key: private_key,
      account_address: account_address,
      contracts: Contracts.all(),
      latest_agent_id: 0,
      next_nonce: fetch_nonce_from_chain(account_address),
      gas_cache: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:account_address, _from, state) do
    {:reply, state.account_address, state}
  end

  def handle_call({:create_agent, class_id, personality}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        total_before = Reader.call_uint(:agent_registry, "totalAgents", [])

        {tx, next_state} =
          submit_contract_transaction(
            :agent_registry,
            "createAgent",
            [normalize_class_id(class_id), normalize_personality(personality)],
            state
          )

        total_after = Reader.call_uint(:agent_registry, "totalAgents", [])
        agent_id = max(total_after, total_before + 1)
        {Map.merge(tx, %{agent_id: agent_id, result: total_after}), %{next_state | latest_agent_id: agent_id}}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:resolve_combat, agent_id, monster_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        ensure_combat_ready!(agent_id, monster_id)
        submit_contract_transaction(:combat_resolver, "resolveCombat", [agent_id, monster_id], state)
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:buy_from_npc, npc_id, item_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        [item_key, price, available] = Reader.call_contract(:npc_registry, "npcPrices", [npc_id, item_id])
        if not available, do: raise("NPC item unavailable")
        {_, state} = ensure_soul_allowance(:npc_registry, price, state)
        {tx, next_state} = submit_contract_transaction(:npc_registry, "buyFromNPC", [npc_id, item_id], state)
        {Map.merge(tx, %{item_id: item_key, price: price}), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:create_market_order, item_id, amount, price}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        {_, state} = ensure_item_approval(:marketplace, state)
        {tx, next_state} = submit_contract_transaction(:marketplace, "createOrder", [item_id, amount, price], state)
        order_id = Reader.call_uint(:marketplace, "totalOrders", [])
        {Map.put(tx, :order_id, order_id), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:fill_market_order, order_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        [_, _, _, price_in_soul, active, _] = Reader.call_contract(:marketplace, "orders", [order_id])
        if not active, do: raise("Order #{order_id} is not active")
        {_, state} = ensure_soul_allowance(:marketplace, price_in_soul, state)
        submit_contract_transaction(:marketplace, "fillOrder", [order_id], state)
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:update_agent_state, agent_id, stats, exp_gained, zone_id, status_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        submit_contract_transaction(
          :agent_registry,
          "updateAgentState",
          [agent_id, encode_stats(stats), exp_gained, zone_id, status_id],
          state
        )
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:distribute_node_rewards, addresses, amounts, epoch}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        submit_contract_transaction(:node_reward_pool, "distributeRewards", [addresses, amounts, epoch], state)
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:distribute_bounty_rewards, addresses, amounts, epoch}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        submit_contract_transaction(:bounty_pool, "distributeRewards", [addresses, amounts, epoch], state)
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:propose_governance_action, proposal_type, title, description, target, call_data}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        submit_contract_transaction(:governance_dao, "propose", [proposal_type, title, description, target, call_data], state)
      end)

    {:reply, reply, next_state}
  end

  def handle_call(:trigger_event_treasury_check, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        submit_contract_transaction(:event_treasury, "checkAndTriggerEvent", [], state)
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

        item_id = Reader.call_uint(:item_registry, "totalItemTypes", [])
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
        {tx, next_state} = submit_contract_transaction(:monster_registry, "registerMonsterType", args, state)
        type_id = Reader.call_uint(:monster_registry, "totalMonsterTypes", [])
        {Map.put(tx, :type_id, type_id), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:spawn_monster, type_id, zone_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        {tx, next_state} = submit_contract_transaction(:monster_registry, "spawnMonster", [type_id, zone_id], state)
        monster_id = Reader.call_uint(:monster_registry, "totalMonsters", [])
        {Map.put(tx, :monster_id, monster_id), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:register_npc_type, name, role, zone_id}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        {tx, next_state} = submit_contract_transaction(:npc_registry, "registerNPCType", [name, role, zone_id], state)
        type_id = Reader.call_uint(:npc_registry, "totalNPCTypes", [])
        {Map.put(tx, :type_id, type_id), next_state}
      end)

    {:reply, reply, next_state}
  end

  def handle_call({:spawn_npc, type_id, zone_id, initial_soul}, _from, state) do
    {reply, next_state} =
      attempt_write(state, fn state ->
        {tx, next_state} = submit_contract_transaction(:npc_registry, "spawnNPC", [type_id, zone_id, initial_soul], state)
        npc_id = Reader.call_uint(:npc_registry, "totalNPCs", [])
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

  defp ensure_soul_allowance(spender_key, required_amount, state) do
    spender = state.contracts[spender_key]
    allowance = Reader.call_uint(:soul_token, "allowance", [state.account_address, spender])

    if allowance >= required_amount do
      {%{status: :already_approved, spender: spender, allowance: allowance}, state}
    else
      amount = required_amount + @approval_padding
      submit_contract_transaction(:soul_token, "approve", [spender, amount], state)
    end
  end

  defp ensure_item_approval(operator_key, state) do
    operator = state.contracts[operator_key]
    approved = Reader.call_bool(:item_registry, "isApprovedForAll", [state.account_address, operator])

    if approved do
      {%{status: :already_approved, operator: operator}, state}
    else
      submit_contract_transaction(:item_registry, "setApprovalForAll", [operator, true], state)
    end
  end

  defp submit_contract_transaction(contract_key, function_name, args, state) do
    {:ok, data} = ABI.encode(function_name, args, abi_name(contract_key))
    nonce = state.next_nonce
    chain_id = fetch_chain_id(state)
    max_priority_fee = fetch_max_priority_fee(state)
    max_fee = fetch_max_fee(state, max_priority_fee)
    to = normalize_address(state.contracts[contract_key])

    {gas_limit, state} =
      estimate_gas(
        %{
          "from" => state.account_address,
          "to" => to,
          "data" => data,
          "value" => quantity(0)
        },
        state,
        {contract_key, function_name}
      )

    case dry_run_transaction(state.account_address, to, data, quantity(0)) do
      :ok ->
        :ok

      {:revert, reason} ->
        raise "Transaction dry run reverted: #{reason}"
    end

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

    case Pool.request(fn url ->
           HttpClient.eth_send_raw_transaction("0x" <> Base.encode16(raw_tx, case: :lower), [url: url])
         end) do
      {:ok, tx_hash} ->
        receipt = wait_for_receipt!(tx_hash, state)

        if quantity_to_integer(Map.get(receipt, "status", "0x1")) != 1 do
          raise "Transaction #{tx_hash} reverted"
        end

        invalidate_related_cache(contract_key, function_name, args)

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

  defp fetch_nonce_from_chain(account_address) do
    case Pool.request(fn url -> HttpClient.eth_get_transaction_count(account_address, "pending", [url: url]) end) do
      {:ok, quantity_hex} -> quantity_to_integer(quantity_hex)
      {:error, reason} -> raise "Unable to fetch nonce: #{inspect(reason)}"
    end
  end

  defp fetch_chain_id(_state) do
    case Pool.request(fn url -> HttpClient.eth_chain_id([url: url]) end) do
      {:ok, quantity_hex} -> quantity_to_integer(quantity_hex)
      {:error, _} -> @chain_id
    end
  end

  defp fetch_max_priority_fee(_state) do
    case Pool.request(fn url -> HttpClient.eth_max_priority_fee_per_gas([url: url]) end) do
      {:ok, quantity_hex} -> quantity_to_integer(quantity_hex)
      {:error, _} -> 100_000_000
    end
  end

  defp fetch_max_fee(_state, max_priority_fee) do
    case Pool.request(fn url -> HttpClient.eth_fee_history("0x1", "latest", [50], [url: url]) end) do
      {:ok, %{"baseFeePerGas" => [base_fee_hex | _]}} ->
        base_fee = quantity_to_integer(base_fee_hex)
        base_fee * 2 + max_priority_fee

      {:error, _} ->
        max_priority_fee * 2
    end
  end

  defp estimate_gas(tx, state, cache_key) do
    now = System.monotonic_time(:millisecond)

    case state.gas_cache[cache_key] do
      %{gas_limit: gas_limit, expires_at: expires_at} when expires_at > now ->
        {gas_limit, state}

      _ ->
        case estimate_gas_with_retry(tx, cache_key) do
          {:ok, quantity_hex} ->
            gas_limit =
              quantity_to_integer(quantity_hex)
              |> Kernel.*(@gas_padding_bps)
              |> div(1_000)

            {
              gas_limit,
              put_in(state.gas_cache[cache_key], %{gas_limit: gas_limit, expires_at: now + @gas_cache_ttl_ms})
            }

          {:error, reason} ->
            if default_gas_limit(cache_key) do
              fallback = default_gas_limit(cache_key)
              Logger.warning(
                "estimateGas fallback for #{inspect(cache_key)} after estimate failure: #{inspect(reason)} -> #{fallback}"
              )

              {
                fallback,
                put_in(
                  state.gas_cache[cache_key],
                  %{gas_limit: fallback, expires_at: now + @gas_cache_ttl_ms}
                )
              }
            else
              raise "eth_estimateGas failed: #{inspect(reason)}"
            end
        end
    end
  end

  defp estimate_gas_with_retry(tx, cache_key, attempts_left \\ @estimate_retry_count)

  defp estimate_gas_with_retry(tx, cache_key, attempts_left) when attempts_left > 0 do
    case Pool.request(fn url -> HttpClient.eth_estimate_gas(tx, [url: url]) end) do
      {:ok, quantity_hex} ->
        {:ok, quantity_hex}

      {:error, reason} ->
        if retryable_estimate_error?(reason) and attempts_left > 1 and is_nil(default_gas_limit(cache_key)) do
          retry_count = @estimate_retry_count - attempts_left + 1
          Logger.warning("estimateGas retry #{retry_count} for #{inspect(cache_key)} after #{inspect(reason)}")
          Process.sleep(@estimate_retry_sleep_ms)
          estimate_gas_with_retry(tx, cache_key, attempts_left - 1)
        else
          {:error, reason}
        end
    end
  end

  defp wait_for_receipt!(tx_hash, state, attempts \\ @max_receipt_polls)

  defp wait_for_receipt!(tx_hash, state, attempts) when attempts > 0 do
    case Pool.request(fn url -> HttpClient.eth_get_transaction_receipt(tx_hash, [url: url]) end) do
      {:ok, nil} ->
        sleep_ms = Enum.at(@receipt_poll_steps, rem(@max_receipt_polls - attempts, length(@receipt_poll_steps)), List.last(@receipt_poll_steps))
        Process.sleep(sleep_ms)
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

  defp dry_run_transaction(from, to, data, value) do
    tx = %{"from" => from, "to" => to, "data" => data, "value" => value}

    case Pool.request(fn url -> HttpClient.eth_call(tx, "latest", [url: url]) end) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        case extract_revert_reason(reason) do
          nil -> :ok
          revert_reason ->
            Logger.error("[writer] revert reason: #{revert_reason}")
            {:revert, revert_reason}
        end
    end
  end

  defp extract_revert_reason(%{"data" => "0x" <> _ = data}), do: ABI.decode_revert(data)
  defp extract_revert_reason(%{"message" => message}), do: message
  defp extract_revert_reason(reason) do
    text = inspect(reason)

    cond do
      String.contains?(text, "AgentNotAlive") -> "AgentNotAlive"
      String.contains?(text, "MonsterNotAlive") -> "MonsterNotAlive"
      String.contains?(text, "InsufficientBalance") -> "InsufficientBalance"
      String.contains?(text, "InsufficientSOUL") -> "InsufficientSOUL"
      String.contains?(text, "OrderNotActive") -> "OrderNotActive"
      String.contains?(text, "ItemNotAvailable") -> "ItemNotAvailable"
      String.contains?(text, "Unauthorized") -> "Unauthorized"
      String.contains?(text, "revert") -> text
      true -> nil
    end
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

  defp normalize_class_id(0), do: 1
  defp normalize_class_id(class_id), do: class_id
  defp normalize_personality(list) when is_list(list) and length(list) == 5, do: Enum.map(list, &normalize_integer/1)

  defp normalize_address("0x" <> _ = address), do: String.downcase(address)
  defp normalize_address(address), do: "0x" <> String.downcase(address)

  defp decode_hex_key!("0x" <> hex), do: Base.decode16!(hex, case: :mixed)
  defp decode_hex_key!(hex), do: Base.decode16!(hex, case: :mixed)

  defp quantity(value), do: "0x" <> Integer.to_string(value, 16)
  defp quantity_to_integer("0x"), do: 0
  defp quantity_to_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp quantity_to_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer("0x"), do: 0
  defp normalize_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp normalize_integer(value), do: value

  defp abi_name(contract_key) do
    contract_key
    |> Atom.to_string()
    |> Macro.camelize()
  end

  defp attempt_write(state, fun) do
    try do
      {payload, next_state} = fun.(state)
      {{:ok, payload}, next_state}
    rescue
      error ->
        {{:error, Exception.message(error)}, %{state | next_nonce: fetch_nonce_from_chain(state.account_address)}}
    end
  end

  defp invalidate_related_cache(:combat_resolver, "resolveCombat", _args) do
    Cache.invalidate_prefix(:monsters)
    Cache.invalidate(:treasury)
  end

  defp invalidate_related_cache(:npc_registry, "buyFromNPC", _args) do
    Cache.invalidate_prefix(:npcs)
  end

  defp invalidate_related_cache(:marketplace, "createOrder", _args) do
    Cache.invalidate(:orders)
  end

  defp invalidate_related_cache(:marketplace, "fillOrder", _args) do
    Cache.invalidate(:orders)
  end

  defp invalidate_related_cache(:marketplace, "fillOrderAFW", _args) do
    Cache.invalidate(:orders)
  end

  defp invalidate_related_cache(:monster_registry, "spawnMonster", _args) do
    Cache.invalidate_prefix(:monsters)
  end

  defp invalidate_related_cache(:npc_registry, "spawnNPC", _args) do
    Cache.invalidate_prefix(:npcs)
  end

  defp invalidate_related_cache(:npc_registry, "setPrice", _args) do
    Cache.invalidate_prefix(:npcs)
  end

  defp invalidate_related_cache(_contract_key, _function_name, _args), do: :ok

  defp ensure_combat_ready!(agent_id, monster_id) do
    agent = Reader.get_agent(agent_id)

    unless agent["statusId"] == 1 or agent["statusName"] in ["ALIVE", "STATUS_1"] do
      raise "Combat precheck failed: agent #{agent_id} is not alive"
    end

    case Reader.call_contract(:monster_registry, "getMonster", [monster_id]) do
      [{_, hp, _, _, _, _, alive}] when alive and hp > 0 -> :ok
      [monster_tuple] -> validate_monster_tuple!(monster_id, monster_tuple)
      _ -> raise "Combat precheck failed: monster #{monster_id} unavailable"
    end
  end

  defp validate_monster_tuple!(_monster_id, {_, hp, _, _, _, _, alive}) when alive and hp > 0, do: :ok
  defp validate_monster_tuple!(monster_id, _), do: raise("Combat precheck failed: monster #{monster_id} is not alive")

  defp default_gas_limit({:combat_resolver, "resolveCombat"}), do: @combat_fallback_gas_limit
  defp default_gas_limit({:npc_registry, "buyFromNPC"}), do: @npc_fallback_gas_limit
  defp default_gas_limit({:marketplace, "createOrder"}), do: @market_fallback_gas_limit
  defp default_gas_limit({:marketplace, "fillOrder"}), do: @market_fallback_gas_limit
  defp default_gas_limit({:agent_registry, "createAgent"}), do: @agent_fallback_gas_limit
  defp default_gas_limit({:agent_registry, "updateAgentState"}), do: @agent_fallback_gas_limit
  defp default_gas_limit(_), do: nil

  defp retryable_estimate_error?(reason) do
    reason
    |> inspect()
    |> String.contains?("521")
  end

  defp encode_stats(%{"hp" => hp, "maxHp" => max_hp, "mp" => mp, "maxMp" => max_mp, "attack" => attack, "defense" => defense, "speed" => speed}) do
    [hp, max_hp, mp, max_mp, attack, defense, speed]
  end

  defp encode_stats(%{hp: hp, max_hp: max_hp, mp: mp, max_mp: max_mp, attack: attack, defense: defense, speed: speed}) do
    [hp, max_hp, mp, max_mp, attack, defense, speed]
  end
end
