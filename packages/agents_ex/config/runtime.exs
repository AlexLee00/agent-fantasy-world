import Config

env_path =
  Path.expand("../../agents/.env", __DIR__)

if File.exists?(env_path) do
  source = Dotenvy.source!(env_path)
  Enum.each(source, fn {key, value} -> System.put_env(key, value) end)
end

deployments_path = Path.expand("../../contracts/deployments.json", __DIR__)

deployments =
  if File.exists?(deployments_path) do
    deployments_path |> File.read!() |> Jason.decode!()
  else
    %{}
  end

contract = fn key ->
  System.get_env("#{String.upcase(key)}_ADDRESS") ||
    Map.get(deployments, key) ||
    raise "Missing contract address for #{key}"
end

optional_contract = fn key ->
  System.get_env("#{String.upcase(key)}_ADDRESS") || Map.get(deployments, key)
end

config :afw,
  rpc_url: System.get_env("RPC_URL", "https://base-sepolia-rpc.publicnode.com"),
  rpc_urls: [
    System.get_env("RPC_URL", "https://base-sepolia-rpc.publicnode.com"),
    System.get_env("RPC_URL_FALLBACK_1", "https://sepolia.base.org"),
    System.get_env("RPC_URL_FALLBACK_2", "https://base-sepolia.blockpi.network/v1/rpc/public")
  ],
  private_key: System.get_env("PRIVATE_KEY", ""),
  github_token: System.get_env("GITHUB_TOKEN", ""),
  github_repo: System.get_env("GITHUB_REPO", "AlexLee00/agent-fantasy-world"),
  brain_tier: String.to_integer(System.get_env("BRAIN_TIER", "1")),
  brain_provider: System.get_env("BRAIN_PROVIDER", "claude-code"),
  afw_basic_api_key: System.get_env("AFW_BASIC_API_KEY", ""),
  openclaw_host: System.get_env("OPENCLAW_HOST", "http://localhost:18789"),
  claude_code_path: System.get_env("CLAUDE_CODE_PATH", "/opt/homebrew/bin/claude"),
  claude_code_model: System.get_env("CLAUDE_CODE_MODEL", "sonnet"),
  claude_code_timeout_ms: String.to_integer(System.get_env("CLAUDE_CODE_TIMEOUT_MS", "45000")),
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY", ""),
  openai_api_key: System.get_env("OPENAI_API_KEY", ""),
  tick_interval_ms: String.to_integer(System.get_env("AGENT_LOOP_INTERVAL", "10")) * 1_000,
  guardian_epoch_ms: String.to_integer(System.get_env("GUARDIAN_EPOCH_MS", "3600000")),
  guardian_dashboard_path:
    System.get_env("GUARDIAN_DASHBOARD_PATH", "../agents/logs/guardian_dashboard.json"),
  economy_metrics_path:
    System.get_env("ECONOMY_METRICS_PATH", "../agents/logs/economy_metrics.json"),
  simulation_metrics_path:
    System.get_env("SIMULATION_METRICS_PATH", "../agents/logs/simulation_metrics.json"),
  memory_log_path: System.get_env("MEMORY_LOG_PATH", "../agents/logs/memory_stream.jsonl"),
  memory_db_path: System.get_env("MEMORY_DB_PATH", "../agents/logs/memory.sqlite3"),
  memory_embedding_provider: System.get_env("MEMORY_EMBEDDING_PROVIDER", "local"),
  ollama_host: System.get_env("OLLAMA_HOST", "http://localhost:11434"),
  memory_embedding_model: System.get_env("MEMORY_EMBEDDING_MODEL", "embeddinggemma"),
  dialogue_log_path: System.get_env("DIALOGUE_LOG_PATH", "../agents/logs/dialogue_stream.jsonl"),
  contribution_proposal_path:
    System.get_env("CONTRIBUTION_PROPOSAL_PATH", "../agents/logs/contribution_proposals"),
  contribution_auto_submit:
    System.get_env("CONTRIBUTION_AUTO_SUBMIT", "false") in ["1", "true", "TRUE"],
  contribution_developer_reward_address:
    System.get_env("CONTRIBUTION_DEVELOPER_REWARD_ADDRESS", ""),
  world_event_cooldown_ms:
    String.to_integer(System.get_env("WORLD_EVENT_COOLDOWN_MS", "1800000")),
  simulation_ticks: String.to_integer(System.get_env("SIMULATION_TICKS", "50")),
  contracts: %{
    afw_token: contract.("AFWToken"),
    soul_token: contract.("SOULToken"),
    world_map: contract.("WorldMap"),
    agent_registry: contract.("AgentRegistry"),
    node_registry: contract.("NodeRegistry"),
    oracle_gateway: contract.("OracleGateway"),
    economy_engine: contract.("EconomyEngine"),
    quest_engine: contract.("QuestEngine"),
    governance_dao: contract.("GovernanceDAO"),
    item_registry: contract.("ItemRegistry"),
    monster_registry: contract.("MonsterRegistry"),
    npc_registry: contract.("NPCRegistry"),
    event_treasury: contract.("EventTreasury"),
    combat_resolver: contract.("CombatResolver"),
    marketplace: contract.("Marketplace"),
    afw_distributor: optional_contract.("AFWDistributor"),
    team_vesting_wallet: optional_contract.("TeamVestingWallet"),
    advisor_vesting_wallet: optional_contract.("AdvisorVestingWallet"),
    node_reward_pool: optional_contract.("NodeRewardPool"),
    bounty_pool: optional_contract.("BountyPool"),
    ecosystem_treasury: optional_contract.("EcosystemTreasury")
  },
  default_agents: [
    %{label: "Warrior", class_id: 1, personality: [90, 10, 30, 80, 50]},
    %{label: "Mage", class_id: 2, personality: [30, 80, 70, 40, 60]},
    %{label: "Ranger", class_id: 3, personality: [50, 50, 90, 50, 50]}
  ]

config :afw, AFWWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT", "4000"))],
  secret_key_base: System.get_env("SECRET_KEY_BASE", String.duplicate("afw_runtime_secret_", 4)),
  server: true
