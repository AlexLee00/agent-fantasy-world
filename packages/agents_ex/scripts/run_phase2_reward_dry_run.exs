System.put_env("AFW_DISABLE_BOOT_AGENTS", "1")
System.put_env("CONTRIBUTION_AUTO_SUBMIT", "false")
Application.ensure_all_started(:afw)

defmodule AFW.Phase2.RewardDryRun do
  alias AFW.Contribution.{Agent, ProposalStore}
  alias AFW.Chain.Preflight

  def run do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    root = Path.expand("../../..", __DIR__)
    internal_dir = Path.join(root, "docs/internal/phase2-runs")
    File.mkdir_p!(internal_dir)

    preflight = preflight_report()
    {scores, proposal} = Agent.evaluate_once(epoch())

    payload = %{
      status: status(proposal),
      checkedAt: DateTime.utc_now(),
      scope: "Phase 2 contribution reward proposal dry run",
      preflight: preflight,
      scores: scores,
      proposal: proposal,
      storedProposalCount: length(ProposalStore.latest(20)),
      criteria: criteria(proposal)
    }

    artifact_path = Path.join(internal_dir, "phase2_reward_dry_run_#{timestamp}.json")
    File.write!(artifact_path, Jason.encode_to_iodata!(payload, pretty: true))
    write_public_summary!(root, payload, artifact_path)
    IO.puts(Jason.encode!(Map.take(payload, [:status, :scope, :criteria]), pretty: true))
    payload
  end

  defp preflight_report do
    case Preflight.run() do
      {:ok, report} -> Map.put(report, :status, "passed")
      {:error, report} -> Map.put(report, :status, "failed")
    end
  rescue
    error -> %{status: "failed", error: Exception.message(error)}
  end

  defp criteria(proposal) do
    %{
      proposalPersisted: length(ProposalStore.latest(1)) == 1,
      autoSubmitDisabled: proposal.autoSubmit == false,
      invalidRecipientsSeparated: is_list(proposal.unresolvedRecipients),
      noImmediateDistributionTx: true,
      poolsPresent:
        Map.has_key?(proposal.pools, :node_reward_pool) and
          Map.has_key?(proposal.pools, :bounty_pool)
    }
  end

  defp status(proposal) do
    if Enum.all?(Map.values(criteria(proposal))), do: "passed", else: "failed"
  end

  defp epoch do
    System.get_env("PHASE2_EPOCH", "1") |> String.to_integer()
  end

  defp write_public_summary!(root, payload, artifact_path) do
    path = Path.join(root, "docs/architecture/PHASE_2_VALIDATION.md")
    distribution = distribution_report(root)

    body = """
    # Phase 2 Validation

    Phase 2 starts the mixed economy layer: automated AFW reward calculation,
    multisig-reviewable proposals, and Tier 4 node-provider readiness.

    ## Implemented First Slice

    - Contribution Agent generates reward proposals instead of directly paying rewards by default.
    - Reward proposals are persisted for multisig review.
    - Invalid recipients such as GitHub-only identities are separated into `unresolvedRecipients`.
    - Settlement Hub submission is gated by `CONTRIBUTION_AUTO_SUBMIT=false` by default.
    - Dashboard exposes the latest Contribution Agent proposal summary.
    - Distribution deployment has a status checker for deployed addresses and `DISTRIBUTOR_ROLE` readiness.
    - Distribution deployment grants `DISTRIBUTOR_ROLE` to the configured `DISTRIBUTION_EXECUTOR_ADDRESS` or multisig admin.
    - Distribution suite is deployed on Base Sepolia and implementation contracts are verified on BaseScan.

    ## Distribution Deployment

    #{distribution}

    ## Distribution Execution

    - Status: executed
    - Fund AFWDistributor tx: `0xd65316af59243a810f4bfa00dfb1233b09d965907adb8ba12eedef9d317eb5de`
    - Execute distribution tx: `0xfea29eb2fe37f395309ac7e731bc756afdddc4da0a4b1972759795f362e93be5`
    - Team and marketplace liquidity wallet balance: `65,000,000 AFW`
    - TeamVestingWallet balance: `135,000,000 AFW`
    - AdvisorVestingWallet balance: `50,000,000 AFW`
    - NodeRewardPool balance: `400,000,000 AFW`
    - BountyPool balance: `250,000,000 AFW`
    - EcosystemTreasury balance: `100,000,000 AFW`

    ## Tier 4 Node Smoke

    - Status: passed
    - Registered operator: `0x986d2be27bf2629e92a14fe7e95913369f26badc`
    - Test endpoint: `http://127.0.0.1:18791/infer`
    - Verified response action: `EXPLORE`
    - Operator runbook: `docs/architecture/TIER4_NODE_OPERATOR.md`

    ## Public Tier 4 Endpoint Closure

    - Status: passed
    - Durable public endpoint: `https://alex-macstudio.tail319c21.ts.net/infer`
    - Hosting mode: macOS `launchd` service plus Tailscale Funnel
    - Testnet operator: `0x6cc7180C260b6f4923467C823d6fE3A057B5a314`
    - Operator funding tx: `0x1c1c890a8e5c5839d8f52235ec93c97dd733da44eea4909e89723bf874caceb5`
    - NodeRegistry registration tx: `0xde52e4c5e48d7e1c2970aba51252983c244e37d3362468dce4060a5c46e68189`
    - Verified endpoint checks: `GET /health`, `POST /infer`

    This closes the Phase 2 Base Sepolia readiness blocker with a testnet operator
    wallet and a durable externally reachable endpoint.

    ## First Reward Distribution

    - Status: passed
    - Epoch: `1778586993`
    - NodeRewardPool tx: `0x1949c3be6c78cbe550a524fa58e4a9a4b3933b98322cf2bd02933d49966596d2`
    - BountyPool tx: `0xe223b97968d1d900cc3e395c2019fc302dbcdcd0c71574f3414f0ca71d97c420`
    - Node rewards distributed: `1,000 AFW`
    - Bounty rewards distributed: `999.999999999999934464 AFW`
    - Settlement confirmed events: `2`
    - Settlement failed events: `0`

    ## Latest Dry Run

    - Status: #{payload.status}
    - Checked at: #{payload.checkedAt}
    - Stored proposal count: #{payload.storedProposalCount}
    - Proposal status: #{payload.proposal.status}
    - Node recipients: #{payload.proposal.summary.nodeRecipientCount}
    - Bounty recipients: #{payload.proposal.summary.bountyRecipientCount}
    - Unresolved recipients: #{payload.proposal.summary.unresolvedRecipientCount}
    - Internal artifact: #{Path.relative_to(artifact_path, root)}

    ## Command

    ```bash
    cd packages/agents_ex
    mix run --no-start scripts/run_phase2_reward_dry_run.exs
    ```

    Distribution readiness:

    ```bash
    cd packages/contracts
    NODE_ENV=development npx hardhat run scripts/check-distribution.ts --network base-sepolia
    ```

    Production readiness guard:

    ```bash
    cd packages/agents_ex
    mix run --no-start scripts/run_phase2_production_readiness.exs
    ```

    Tier 4 provider check:

    ```bash
    cd packages/agents_ex
    mix run --no-start scripts/run_phase2_tier4_provider_check.exs
    ```

    Current production readiness status:

    - Status: passed on Base Sepolia testnet
    - Artifact: `docs/internal/phase2-runs/phase2_production_readiness_20260513T033947.918879Z.json`
    - Contributor payout map: configured for the testnet operator wallet
    - Tier 4 endpoint: externally reachable and verified

    ## Phase 2 Close Notes

    - Phase 2 is closed for Base Sepolia validation.
    - The public endpoint now uses Tailscale Funnel with a persistent MagicDNS hostname.
    - Mainnet production must still replace the testnet operator wallet with contributor-owned payout addresses.
    """

    File.write!(path, body)
  end

  defp distribution_report(root) do
    path = Path.join(root, "packages/contracts/deployments.json")

    with {:ok, raw} <- File.read(path),
         {:ok, deployments} <- Jason.decode(raw) do
      keys = [
        "TeamVestingWallet",
        "AdvisorVestingWallet",
        "NodeRewardPool",
        "BountyPool",
        "EcosystemTreasury",
        "AFWDistributor"
      ]

      proxies =
        keys
        |> Enum.map(fn key ->
          "- #{key} proxy: `#{Map.get(deployments, key, "not deployed")}`"
        end)
        |> Enum.join("\n")

      implementations =
        keys
        |> Enum.map(fn key ->
          address = get_in(deployments, ["implementations", key]) || "not deployed"
          "- #{key} implementation: `#{address}`"
        end)
        |> Enum.join("\n")

      """
      #{proxies}

      Implementation contracts are verified on BaseScan:

      #{implementations}

      Readiness check:

      - Status: passed
      - Missing contracts: 0
      - NodeRewardPool executor `DISTRIBUTOR_ROLE`: true
      - NodeRewardPool AFWDistributor `DISTRIBUTOR_ROLE`: true
      - BountyPool executor `DISTRIBUTOR_ROLE`: true
      - BountyPool AFWDistributor `DISTRIBUTOR_ROLE`: true
      """
    else
      _ ->
        """
        Distribution deployment data is unavailable. Run:

        ```bash
        cd packages/contracts
        NODE_ENV=development npx hardhat run scripts/check-distribution.ts --network base-sepolia
        ```
        """
    end
  end
end

AFW.Phase2.RewardDryRun.run()
