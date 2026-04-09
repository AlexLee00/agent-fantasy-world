defmodule AFW.Guardian.Monitor do
  @moduledoc "Guardian GenServer that monitors on-chain activity and publishes analytics."
  use GenServer

  alias AFW.Chain.Client
  alias AFW.Guardian.Analyzer
  alias AFW.Guardian.Dashboard

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_poll()
    {:ok, Map.put(state, :history, [])}
  end

  @impl true
  def handle_info(:poll, state) do
    metrics = Client.soul_metrics()

    payload =
      Analyzer.analyze([], %{
        total_minted: metrics.total_minted,
        total_burned: metrics.total_burned,
        total_supply: metrics.total_supply,
        agent_count: 3,
        average_level: 1.0,
        wealth_gini: 0.0,
        combat_count: 0,
        agent_win_rate: 0.0,
        death_count: 0,
        treasury_balance: Client.get_treasury_balance(),
        next_event: "MINI at 1000"
      })

    _ = Dashboard.write(payload)
    Phoenix.PubSub.broadcast(AFW.PubSub, "guardian", {:guardian_metrics, payload})
    schedule_poll()
    {:noreply, state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, 10_000)
  end
end
