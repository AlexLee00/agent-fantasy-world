from __future__ import annotations

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    rpc_url: str = Field(default="http://127.0.0.1:8545", alias="RPC_URL")
    private_key: str = Field(alias="PRIVATE_KEY")
    agent_registry_address: str = Field(alias="AGENT_REGISTRY_ADDRESS")
    soul_token_address: str = Field(alias="SOUL_TOKEN_ADDRESS")
    world_map_address: str = Field(alias="WORLD_MAP_ADDRESS")
    economy_engine_address: str = Field(alias="ECONOMY_ENGINE_ADDRESS")
    quest_engine_address: str = Field(alias="QUEST_ENGINE_ADDRESS")
    governance_dao_address: str = Field(alias="GOVERNANCE_DAO_ADDRESS")
    monster_registry_address: str = Field(alias="MONSTER_REGISTRY_ADDRESS")
    npc_registry_address: str = Field(alias="NPC_REGISTRY_ADDRESS")
    item_registry_address: str = Field(alias="ITEM_REGISTRY_ADDRESS")
    combat_resolver_address: str = Field(alias="COMBAT_RESOLVER_ADDRESS")
    marketplace_address: str = Field(alias="MARKETPLACE_ADDRESS")
    event_treasury_address: str = Field(alias="EVENT_TREASURY_ADDRESS")

    brain_provider: str = Field(default="openai", alias="BRAIN_PROVIDER")
    claude_code_path: str = Field(default="/opt/homebrew/bin/claude", alias="CLAUDE_CODE_PATH")
    claude_code_model: str = Field(default="sonnet", alias="CLAUDE_CODE_MODEL")
    claude_code_name: str = Field(default="", alias="CLAUDE_CODE_NAME")
    claude_code_settings: str = Field(default="", alias="CLAUDE_CODE_SETTINGS")
    claude_code_agent: str = Field(default="", alias="CLAUDE_CODE_AGENT")
    claude_code_timeout_ms: int = Field(default=45000, alias="CLAUDE_CODE_TIMEOUT_MS")
    openai_api_key: str = Field(default="", alias="OPENAI_API_KEY")
    openai_model: str = Field(default="gpt-4o-mini", alias="OPENAI_MODEL")
    openai_oauth_client_id: str = Field(default="", alias="OPENAI_OAUTH_CLIENT_ID")
    openai_oauth_client_secret: str = Field(default="", alias="OPENAI_OAUTH_CLIENT_SECRET")
    openai_oauth_redirect_uri: str = Field(
        default="http://localhost:8080/callback",
        alias="OPENAI_OAUTH_REDIRECT_URI",
    )
    openai_oauth_token_path: str = Field(
        default=".oauth/openai_token.json",
        alias="OPENAI_OAUTH_TOKEN_PATH",
    )
    codex_auth_file: str = Field(default="~/.codex/auth.json", alias="CODEX_AUTH_FILE")
    openclaw_auth_file: str = Field(
        default="~/.openclaw/agents/main/agent/auth-profiles.json",
        alias="OPENCLAW_AUTH_FILE",
    )
    openclaw_auth_provider: str = Field(default="openai-codex", alias="OPENCLAW_AUTH_PROVIDER")
    openclaw_auth_profile: str = Field(default="", alias="OPENCLAW_AUTH_PROFILE")
    anthropic_api_key: str = Field(default="", alias="ANTHROPIC_API_KEY")
    anthropic_model: str = Field(default="claude-sonnet-4-20250514", alias="ANTHROPIC_MODEL")

    agent_loop_interval: int = Field(default=10, alias="AGENT_LOOP_INTERVAL")
    agent_class: int = Field(default=1, alias="AGENT_CLASS")
    agent_personality: str = Field(default="70,30,50,80,60", alias="AGENT_PERSONALITY")
    guardian_dashboard_path: str = Field(default="logs/guardian_dashboard.json", alias="GUARDIAN_DASHBOARD_PATH")
    economy_metrics_path: str = Field(default="logs/economy_metrics.json", alias="ECONOMY_METRICS_PATH")
    simulation_ticks: int = Field(default=50, alias="SIMULATION_TICKS")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    def parsed_personality(self) -> list[int]:
        values = [int(part.strip()) for part in self.agent_personality.split(",") if part.strip()]
        if len(values) != 5:
            raise ValueError("AGENT_PERSONALITY must contain exactly 5 comma-separated integers")
        for value in values:
            if value < 0 or value > 100:
                raise ValueError("AGENT_PERSONALITY values must be between 0 and 100")
        return values

    def normalized_agent_class(self) -> int:
        # Accept the legacy Warrior enum value (0) and map it to the new registry id (1).
        if self.agent_class == 0:
            return 1
        return self.agent_class
