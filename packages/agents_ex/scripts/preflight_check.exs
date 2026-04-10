Application.ensure_all_started(:afw)

alias AFW.Chain.Client
alias Ethereumex.HttpClient

rpc_url = Application.fetch_env!(:afw, :rpc_url)
deployer = Client.account_address()
{:ok, eth_balance_hex} = HttpClient.eth_get_balance(deployer, "latest", url: rpc_url)
eth_balance = String.to_integer(String.replace_prefix(eth_balance_hex, "0x", ""), 16)

snapshot = %{
  treasury: Client.get_treasury_balance(),
  monsters_zone1: length(Client.get_monsters_in_zone(1)),
  npcs_zone1: length(Client.get_npcs_in_zone(1)),
  orders: length(Client.active_orders()),
  agent22: Client.get_agent(22),
  agent23: Client.get_agent(23),
  agent24: Client.get_agent(24),
  soul22: Client.get_soul_balance(Client.get_agent(22)["observer"]),
  soul23: Client.get_soul_balance(Client.get_agent(23)["observer"]),
  soul24: Client.get_soul_balance(Client.get_agent(24)["observer"]),
  deployer: deployer,
  deployerEth: eth_balance
}

IO.puts(Jason.encode!(snapshot, pretty: true))
