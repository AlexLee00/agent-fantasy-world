Application.ensure_all_started(:afw)

case AFW.Chain.Preflight.run() do
  {:ok, report} ->
    IO.puts(Jason.encode!(report, pretty: true))

  {:error, report} ->
    IO.puts(Jason.encode!(report, pretty: true))
    System.halt(1)
end
