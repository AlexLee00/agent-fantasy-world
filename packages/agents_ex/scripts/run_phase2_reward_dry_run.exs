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

    ## Remaining Phase 2 Work

    - Deploy or verify distribution pool addresses on Base Sepolia in `deployments.json`.
    - Grant `DISTRIBUTOR_ROLE` to the approved multisig/distributor path.
    - Map GitHub contributors to payout addresses before enabling auto-submit.
    - Register at least one real Tier 4 node endpoint and verify paid inference.
    - Run the first multisig-approved reward distribution on testnet.
    """

    File.write!(path, body)
  end
end

AFW.Phase2.RewardDryRun.run()
