System.put_env("AFW_DISABLE_BOOT_AGENTS", "1")
Application.ensure_all_started(:afw)

defmodule AFW.Phase2.ProductionReadiness do
  alias AFW.Contribution.Readiness

  def run do
    root = Path.expand("../../..", __DIR__)
    internal_dir = Path.join(root, "docs/internal/phase2-runs")
    File.mkdir_p!(internal_dir)

    report = Readiness.check()
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    artifact_path = Path.join(internal_dir, "phase2_production_readiness_#{timestamp}.json")
    File.write!(artifact_path, Jason.encode_to_iodata!(report, pretty: true))

    IO.puts(Jason.encode!(Map.put(report, :artifact, Path.relative_to(artifact_path, root)), pretty: true))

    if System.get_env("PHASE2_READINESS_STRICT", "false") in ["1", "true", "TRUE"] and
         report.status != :passed do
      System.halt(1)
    end

    report
  end
end

AFW.Phase2.ProductionReadiness.run()
