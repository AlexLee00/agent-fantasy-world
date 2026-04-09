from __future__ import annotations

import asyncio
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from web3 import Web3

from src.agent.loop import AgentLoop
from src.brain.claude_code_provider import ClaudeCodeProvider
from src.brain.prompt_builder import PromptBuilder
from src.chain.client import ChainClient
from src.config import Settings
from src.guardian import GuardianAnalyzer, GuardianMonitor, write_guardian_dashboard


AGENT_PROFILES = [
    ("Warrior", 1, "90,10,30,80,50"),
    ("Mage", 2, "30,80,70,40,60"),
    ("Ranger", 3, "50,50,90,50,50"),
]


def derived_private_key(label: str) -> str:
    digest = Web3.keccak(text=f"afw-sim::{label}")
    return "0x" + digest.hex()


async def main() -> None:
    settings = Settings()
    admin_chain = ChainClient(settings)
    admin_chain.ensure_minter_role()

    loops: list[AgentLoop] = []
    for label, class_id, personality in AGENT_PROFILES:
        private_key = derived_private_key(label)
        child_settings = settings.model_copy(
            update={
                "private_key": private_key,
                "agent_class": class_id,
                "agent_personality": personality,
            }
        )
        child_chain = ChainClient(child_settings)
        admin_chain.fund_address(child_chain.address, admin_chain.w3.to_wei(0.003, "ether"))
        admin_chain.mint_soul(child_chain.address, admin_chain.w3.to_wei(100, "ether"), "SIM_BOOTSTRAP", 0)

        brain = ClaudeCodeProvider(
            cli_path=settings.claude_code_path,
            model=settings.claude_code_model,
            timeout_ms=settings.claude_code_timeout_ms,
            session_name=f"afw-{label.lower()}",
            settings_file=settings.claude_code_settings,
            agent=settings.claude_code_agent,
        )
        loops.append(AgentLoop(child_chain, brain, PromptBuilder(), child_settings, label=label))

    await asyncio.gather(*(loop.start(max_ticks=settings.simulation_ticks) for loop in loops))

    metrics = {
        "totalSOUL": admin_chain.get_total_supply_snapshot(),
        "agents": [
            {
                "label": loop.label,
                "agentId": loop.agent_id,
                "wallet": loop.chain.address,
                "soulBalance": loop.chain.get_soul_balance(),
                "tickCount": loop.tick_count,
            }
            for loop in loops
        ],
        "combatLogs": admin_chain.get_combat_logs(max(0, admin_chain.w3.eth.block_number - 500)),
        "marketLogs": admin_chain.get_market_logs(max(0, admin_chain.w3.eth.block_number - 500)),
        "treasuryBalance": admin_chain.get_treasury_balance(),
    }

    output_path = Path(settings.economy_metrics_path)
    if not output_path.is_absolute():
        output_path = Path.cwd() / output_path
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")

    monitor = GuardianMonitor(admin_chain)
    analyzer = GuardianAnalyzer(admin_chain)
    dashboard = analyzer.analyze(monitor.poll())
    write_guardian_dashboard(settings.guardian_dashboard_path, dashboard)

    print(f"Economy metrics written to {output_path}")


if __name__ == "__main__":
    asyncio.run(main())
