Application.ensure_all_started(:afw)

alias AFW.Chain.{Client, Preflight, ReceiptDiagnostics}

timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
root = Path.expand("../../..", __DIR__)
artifact_dir = Path.join(root, "docs/internal/phase0-runs")
File.mkdir_p!(artifact_dir)

case Preflight.run() do
  {:ok, report} ->
    IO.puts("Preflight OK: #{length(report.checks)} checks")

  {:error, report} ->
    path = Path.join(artifact_dir, "writer_smoke_preflight_failed_#{timestamp}.json")
    File.write!(path, Jason.encode_to_iodata!(report, pretty: true))
    raise "Preflight failed. Details written to #{path}"
end

agent_id =
  System.get_env("PHASE0_SMOKE_AGENT_ID", "22")
  |> String.to_integer()

agent = Client.get_agent_fresh_state(agent_id)
started_at = System.monotonic_time(:millisecond)

result =
  Client.update_agent_state(
    agent_id,
    agent["stats"],
    0,
    agent["zoneId"],
    agent["statusId"]
  )

duration_ms = System.monotonic_time(:millisecond) - started_at

payload =
  case result do
    {:ok, tx} ->
      %{
        status: "confirmed",
        agentId: agent_id,
        txHash: tx.tx_hash,
        baseScan: ReceiptDiagnostics.basescan_tx_url(tx.tx_hash),
        durationMs: duration_ms,
        receiptStatus: tx.receipt["status"],
        blockNumber: tx.receipt["blockNumber"],
        checkedAt: DateTime.utc_now()
      }

    {:error, reason} ->
      %{
        status: "failed",
        agentId: agent_id,
        reason: reason,
        durationMs: duration_ms,
        checkedAt: DateTime.utc_now()
      }
  end

path = Path.join(artifact_dir, "writer_smoke_#{timestamp}.json")
File.write!(path, Jason.encode_to_iodata!(payload, pretty: true))
IO.puts(Jason.encode!(payload, pretty: true))

if payload.status != "confirmed" or payload.durationMs > 30_000 do
  raise "Writer smoke failed or exceeded 30s. Artifact: #{path}"
end
