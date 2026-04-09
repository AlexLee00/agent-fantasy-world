from __future__ import annotations

import asyncio

from src.agent.loop import AgentLoop
from src.brain.anthropic_provider import AnthropicProvider
from src.brain.claude_code_provider import ClaudeCodeProvider
from src.brain.codex_provider import CodexOAuthProvider
from src.brain.oauth_flow import ensure_experimental_openai_oauth
from src.brain.openclaw_provider import OpenClawOAuthProvider
from src.brain.openai_provider import OpenAIProvider
from src.brain.prompt_builder import PromptBuilder
from src.chain.client import ChainClient
from src.config import Settings


async def main():
    settings = Settings()

    print("🏰 Agent Fantasy World - Agent Engine v0.1")
    active_model = settings.claude_code_model if settings.brain_provider == "claude-code" else settings.openai_model
    print(f"   Provider: {settings.brain_provider} ({active_model})")
    print(f"   RPC: {settings.rpc_url}")
    print()

    chain = ChainClient(settings)
    granted = chain.ensure_oracle_role()
    if granted:
        print(f"   Granted ORACLE_ROLE to {chain.address}")
    funded = chain.ensure_initial_soul(50)
    if funded:
        print(f"   Minted initial SOUL funding to {chain.address}")

    if settings.brain_provider == "claude-code":
        brain = ClaudeCodeProvider(
            cli_path=settings.claude_code_path,
            model=settings.claude_code_model,
            timeout_ms=settings.claude_code_timeout_ms,
            session_name=settings.claude_code_name,
            settings_file=settings.claude_code_settings,
            agent=settings.claude_code_agent,
        )
    elif settings.brain_provider == "openclaw":
        brain = OpenClawOAuthProvider(
            settings.openclaw_auth_file,
            provider=settings.openclaw_auth_provider,
            profile_key=settings.openclaw_auth_profile,
            model=settings.openai_model,
        )
    elif settings.brain_provider == "codex":
        brain = CodexOAuthProvider(settings.codex_auth_file, settings.openai_model)
    elif settings.brain_provider == "oauth":
        brain = await ensure_experimental_openai_oauth(settings)
    elif settings.brain_provider == "anthropic":
        brain = AnthropicProvider(settings.anthropic_api_key, settings.anthropic_model)
    else:
        brain = OpenAIProvider(settings.openai_api_key, settings.openai_model)

    prompt_builder = PromptBuilder()
    loop = AgentLoop(chain, brain, prompt_builder, settings)
    await loop.start()


if __name__ == "__main__":
    asyncio.run(main())
