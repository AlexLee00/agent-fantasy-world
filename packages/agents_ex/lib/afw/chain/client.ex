defmodule AFW.Chain.Client do
  @moduledoc "Public AFW chain facade delegating reads to Reader and writes to Writer."

  alias AFW.Chain.{Preflight, Reader, Writer}

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

  def snapshot(agent_id), do: Reader.snapshot(agent_id)
  def get_treasury_balance, do: Reader.get_treasury_balance()
  def get_agent(agent_id), do: Reader.get_agent(agent_id)
  def get_zone(zone_id), do: Reader.get_zone(zone_id)
  def get_monsters_in_zone(zone_id), do: Reader.get_monsters_in_zone(zone_id)
  def get_alive_monsters_in_zone(zone_id), do: Reader.get_alive_monsters_in_zone(zone_id)
  def get_npcs_in_zone(zone_id), do: Reader.get_npcs_in_zone(zone_id)
  def get_npc_fresh(npc_id), do: Reader.get_npc_fresh(npc_id)
  def get_agent_items(address), do: Reader.get_agent_items(address)
  def get_agent_fresh_state(agent_id), do: Reader.get_agent_fresh_state(agent_id)
  def get_monster_fresh(monster_id), do: Reader.get_monster_fresh(monster_id)
  def get_node_stats, do: Reader.get_node_stats()
  def get_creator_stats, do: Reader.get_creator_stats()
  def get_soul_balance(address), do: Reader.get_soul_balance(address)
  def get_npc_price(npc_id, item_id), do: Reader.get_npc_price(npc_id, item_id)
  def find_item_type_id(name), do: Reader.find_item_type_id(name)
  def active_orders, do: Reader.active_orders()
  def get_active_orders, do: Reader.get_active_orders()
  def soul_metrics, do: Reader.soul_metrics()
  def tracked_contracts, do: @tracked_contracts
  def account_address, do: Writer.account_address()
  def preflight, do: Preflight.run()

  def create_agent(class_id, personality), do: Writer.create_agent(class_id, personality)
  def resolve_combat(agent_id, monster_id), do: Writer.resolve_combat(agent_id, monster_id)
  def buy_from_npc(npc_id, item_id), do: Writer.buy_from_npc(npc_id, item_id)

  def create_market_order(item_id, amount, price),
    do: Writer.create_market_order(item_id, amount, price)

  def fill_market_order(order_id), do: Writer.fill_market_order(order_id)

  def update_agent_state(agent_id, stats, exp_gained, zone_id, status_id),
    do: Writer.update_agent_state(agent_id, stats, exp_gained, zone_id, status_id)

  def distribute_node_rewards(addresses, amounts, epoch),
    do: Writer.distribute_node_rewards(addresses, amounts, epoch)

  def distribute_bounty_rewards(addresses, amounts, epoch),
    do: Writer.distribute_bounty_rewards(addresses, amounts, epoch)

  def propose_governance_action(proposal_type, title, description, target, call_data),
    do: Writer.propose_governance_action(proposal_type, title, description, target, call_data)

  def trigger_event_treasury_check, do: Writer.trigger_event_treasury_check()

  def register_item_type(name, category, tier, min_stat, max_stat, tradeable) do
    Writer.register_item_type(name, category, tier, min_stat, max_stat, tradeable)
  end

  def register_monster_type(attrs), do: Writer.register_monster_type(attrs)
  def spawn_monster(type_id, zone_id), do: Writer.spawn_monster(type_id, zone_id)
  def register_npc_type(name, role, zone_id), do: Writer.register_npc_type(name, role, zone_id)

  def spawn_npc(type_id, zone_id, initial_soul),
    do: Writer.spawn_npc(type_id, zone_id, initial_soul)

  def set_npc_price(npc_id, item_id, price), do: Writer.set_npc_price(npc_id, item_id, price)
end
