defmodule AFW.Guardian.Metrics do
  @moduledoc "Tracks Guardian epochs, anomaly counts, and proposal submissions."
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(
      __MODULE__,
      %{epochs: 0, anomalies: 0, highest_severity: "none", proposals: 0, last: nil},
      name: __MODULE__
    )
  end

  @impl true
  def init(state), do: {:ok, state}

  def record_epoch(payload), do: GenServer.cast(__MODULE__, {:epoch, payload})
  def record_proposal, do: GenServer.cast(__MODULE__, :proposal)
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  @impl true
  def handle_cast({:epoch, payload}, state) do
    anomalies = length(payload[:anomalies] || [])
    severity = payload[:severity] || "none"

    {:noreply,
     %{
       state
       | epochs: state.epochs + 1,
         anomalies: state.anomalies + anomalies,
         highest_severity: max_severity(state.highest_severity, severity),
         last: %{severity: severity, anomalies: anomalies, at: DateTime.utc_now()}
     }}
  end

  def handle_cast(:proposal, state) do
    {:noreply, %{state | proposals: state.proposals + 1}}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply,
     %{
       epochsAnalyzed: state.epochs,
       anomaliesDetected: state.anomalies,
       highestSeverity: state.highest_severity,
       proposalsCreated: state.proposals,
       lastEpoch: state.last
     }, state}
  end

  defp max_severity(current, incoming) do
    rank = %{"none" => 0, "low" => 1, "medium" => 2, "high" => 3, "critical" => 4}
    if rank[incoming] >= rank[current], do: incoming, else: current
  end
end
