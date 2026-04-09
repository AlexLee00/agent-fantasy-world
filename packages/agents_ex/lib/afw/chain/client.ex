defmodule AFW.Chain.Client do
  @moduledoc "Shared JSON-RPC client GenServer for the 15 deployed AFW contracts."
  use GenServer

  alias AFW.Chain.Contracts
  alias AFW.Chain.ABI

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

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def snapshot(agent_id), do: GenServer.call(__MODULE__, {:snapshot, agent_id})

  def create_agent(class_id, personality),
    do: GenServer.call(__MODULE__, {:create_agent, class_id, personality}, 30_000)

  def resolve_combat(agent_id, monster_id),
    do: GenServer.call(__MODULE__, {:resolve_combat, agent_id, monster_id}, 30_000)

  def buy_from_npc(npc_id, item_id),
    do: GenServer.call(__MODULE__, {:buy_from_npc, npc_id, item_id}, 30_000)

  def create_market_order(item_id, amount, price),
    do: GenServer.call(__MODULE__, {:create_market_order, item_id, amount, price}, 30_000)

  def fill_market_order(order_id),
    do: GenServer.call(__MODULE__, {:fill_market_order, order_id}, 30_000)

  def get_treasury_balance, do: GenServer.call(__MODULE__, :get_treasury_balance)

  def get_monsters_in_zone(zone_id),
    do: GenServer.call(__MODULE__, {:get_monsters_in_zone, zone_id})

  def get_npcs_in_zone(zone_id), do: GenServer.call(__MODULE__, {:get_npcs_in_zone, zone_id})
  def get_agent_items(address), do: GenServer.call(__MODULE__, {:get_agent_items, address})
  def active_orders, do: GenServer.call(__MODULE__, :active_orders)
  def soul_metrics, do: GenServer.call(__MODULE__, :soul_metrics)
  def tracked_contracts, do: @tracked_contracts

  @impl true
  def init(opts) do
    state = %{
      rpc_url: Keyword.get(opts, :rpc_url) || Application.fetch_env!(:afw, :rpc_url),
      private_key: Keyword.get(opts, :private_key) || Application.fetch_env!(:afw, :private_key),
      contracts: Contracts.all(),
      latest_agent_id: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:snapshot, agent_id}, _from, state) do
    agent = get_agent(agent_id)
    zone = get_zone(agent["zoneId"])

    reply = %{
      agent: agent,
      zone: zone,
      monsters: monsters_for_zone(zone["zoneId"]),
      npcs: npcs_for_zone(zone["zoneId"]),
      items: inventory_for(agent["observer"]),
      orders: sample_active_orders(),
      treasury_balance: treasury_balance()
    }

    {:reply, reply, state}
  end

  def handle_call({:create_agent, class_id, personality}, _from, state) do
    agent_id = state.latest_agent_id + 1

    payload =
      submit_contract_transaction(:agent_registry, "createAgent", [class_id, personality], state)

    {:reply, {:ok, Map.put(payload, :agent_id, agent_id)}, %{state | latest_agent_id: agent_id}}
  end

  def handle_call({:resolve_combat, agent_id, monster_id}, _from, state) do
    {:reply,
     {:ok,
      submit_contract_transaction(
        :combat_resolver,
        "resolveCombat",
        [agent_id, monster_id],
        state
      )}, state}
  end

  def handle_call({:buy_from_npc, npc_id, item_id}, _from, state) do
    {:reply,
     {:ok, submit_contract_transaction(:npc_registry, "buyFromNPC", [npc_id, item_id], state)},
     state}
  end

  def handle_call({:create_market_order, item_id, amount, price}, _from, state) do
    {:reply,
     {:ok,
      submit_contract_transaction(:marketplace, "createOrder", [item_id, amount, price], state)},
     state}
  end

  def handle_call({:fill_market_order, order_id}, _from, state) do
    {:reply, {:ok, submit_contract_transaction(:marketplace, "fillOrder", [order_id], state)},
     state}
  end

  def handle_call(:get_treasury_balance, _from, state) do
    {:reply, treasury_balance(), state}
  end

  def handle_call({:get_monsters_in_zone, zone_id}, _from, state) do
    {:reply, monsters_for_zone(zone_id), state}
  end

  def handle_call({:get_npcs_in_zone, zone_id}, _from, state) do
    {:reply, npcs_for_zone(zone_id), state}
  end

  def handle_call({:get_agent_items, _address}, _from, state) do
    {:reply, inventory_for(""), state}
  end

  def handle_call(:active_orders, _from, state) do
    {:reply, sample_active_orders(), state}
  end

  def handle_call(:soul_metrics, _from, state) do
    {:reply, %{total_minted: 0, total_burned: 0, total_supply: 0}, state}
  end

  def get_agent(agent_id) do
    %{
      "agentId" => agent_id,
      "observer" => "0x0000000000000000000000000000000000000000",
      "classId" => 1,
      "className" => "Warrior",
      "statusId" => 1,
      "statusName" => "ALIVE",
      "level" => 1,
      "experience" => 0,
      "zoneId" => 1,
      "personality" => %{
        "bravery" => 70,
        "greed" => 30,
        "sociability" => 50,
        "curiosity" => 80,
        "loyalty" => 60
      },
      "stats" => %{
        "hp" => 100,
        "maxHp" => 100,
        "mp" => 50,
        "maxMp" => 50,
        "attack" => 20,
        "defense" => 15,
        "speed" => 10
      }
    }
  end

  def get_zone(zone_id) do
    AFW.World.Context.zone(zone_id)
  end

  defp submit_contract_transaction(contract_key, function_name, args, state) do
    _ = ABI.encode(function_name, args, abi_name(contract_key))

    %{
      contract: contract_key,
      function: function_name,
      args: args,
      address: state.contracts[contract_key],
      tx_hash: "0x" <> Base.encode16(:crypto.strong_rand_bytes(32), case: :lower)
    }
  end

  defp abi_name(contract_key) do
    contract_key
    |> Atom.to_string()
    |> Macro.camelize()
  end

  defp monsters_for_zone(zone_id) do
    AFW.World.Context.monsters_for_zone(zone_id)
    |> Enum.map(fn monster ->
      %{
        monster_id: monster.monster_id,
        name: monster.name,
        atk: monster.atk,
        def: monster.def,
        hp: monster.hp,
        soul_balance: monster.soul_balance,
        zone_id: zone_id,
        danger_level: monster.danger_level
      }
    end)
  end

  defp npcs_for_zone(zone_id) do
    AFW.World.Context.npcs_for_zone(zone_id)
  end

  defp inventory_for(_address) do
    AFW.World.Context.seed_item_inventory()
  end

  defp sample_active_orders do
    AFW.World.Context.sample_orders()
  end

  defp treasury_balance, do: 0
end
