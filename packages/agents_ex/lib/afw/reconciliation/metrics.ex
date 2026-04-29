defmodule AFW.Reconciliation.Metrics do
  @moduledoc "Tracks reconciliation pass counts and mismatches."
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{checks: 0, mismatches: 0, corrections: 0, last: nil},
      name: __MODULE__
    )
  end

  @impl true
  def init(state), do: {:ok, state}

  def record(check_size, mismatch_count) do
    GenServer.cast(__MODULE__, {:record, check_size, mismatch_count})
  end

  def snapshot do
    GenServer.call(__MODULE__, :snapshot)
  end

  @impl true
  def handle_cast({:record, check_size, mismatch_count}, state) do
    {:noreply,
     %{
       state
       | checks: state.checks + 1,
         mismatches: state.mismatches + mismatch_count,
         corrections: state.corrections + mismatch_count,
         last: %{agents: check_size, mismatches: mismatch_count, at: DateTime.utc_now()}
     }}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply,
     %{
       checksPerformed: state.checks,
       mismatchesFound: state.mismatches,
       correctionsApplied: state.corrections,
       lastCheck: state.last
     }, state}
  end
end
