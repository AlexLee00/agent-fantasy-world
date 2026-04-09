from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.chain.client import ChainClient
from src.config import Settings
from src.guardian import GuardianAnalyzer, GuardianMonitor, GuardianProposer, write_guardian_dashboard


def main() -> None:
    settings = Settings()
    chain = ChainClient(settings)
    monitor = GuardianMonitor(chain)
    analyzer = GuardianAnalyzer(chain)
    proposer = GuardianProposer(chain)

    batch = monitor.poll()
    dashboard = analyzer.analyze(batch)

    alerts = []
    for anomaly in dashboard["anomalies"]:
        evidence = {"txHash": anomaly["txHash"], "pattern": anomaly["pattern"], "details": anomaly["details"]}
        if anomaly["pattern"] == "UNAUTHORIZED_MINT_FLOW":
            alerts.append(proposer.build_freeze_proposal(chain.address, anomaly["details"], evidence))
    dashboard["alerts"] = alerts

    output = write_guardian_dashboard(settings.guardian_dashboard_path, dashboard)
    print(f"Guardian dashboard written to {output}")


if __name__ == "__main__":
    main()
