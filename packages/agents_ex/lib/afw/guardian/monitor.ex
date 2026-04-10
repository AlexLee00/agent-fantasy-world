defmodule AFW.Guardian.Monitor do
  @moduledoc "Guardian GenServer that monitors on-chain activity and publishes analytics."
  use GenServer
  require Logger

  alias AFW.Brain.Interface
  alias AFW.Chain.Client
  alias AFW.Guardian.Metrics, as: GuardianMetrics
  alias AFW.Guardian.{Analyzer, Dashboard, Economics, Proposer}
  alias AFW.Settlement.Hub
  alias AFW.Simulation.Balance

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def force_epoch do
    GenServer.cast(__MODULE__, :force_epoch)
  end

  @impl true
  def init(state) do
    Phoenix.PubSub.subscribe(AFW.PubSub, "guardian")
    schedule_epoch()

    {:ok,
     state
     |> Map.put(:epoch_events, [])
     |> Map.put(:mismatches, %{})
     |> Map.put(:world_events, %{})}
  end

  @impl true
  def handle_cast(:force_epoch, state) do
    send(self(), :epoch)
    {:noreply, state}
  end

  @impl true
  def handle_info(:epoch, state) do
    queued = Hub.queued_events_snapshot()
    economics = Economics.snapshot()
    events = Enum.reverse(state.epoch_events) ++ mismatch_events(state.mismatches)
    ai_analysis = brain_analysis(events, economics)
    epoch_no = GuardianMetrics.snapshot().epochsAnalyzed + 1

    Logger.info("[guardian] epoch #{epoch_no} started: scanning #{length(events ++ queued)} events")

    payload =
      Analyzer.analyze(events ++ queued, %{
        soul: economics.soul,
        wealth: economics.wealth,
        combat: economics.combat,
        treasury: economics.treasury,
        total_minted: economics.soul.total_minted,
        total_burned: economics.soul.total_burned,
        total_supply: economics.soul.circulating,
        wealth_gini: economics.wealth.gini,
        combat_count: economics.combat.total_fights,
        agent_win_rate: economics.combat.win_rate,
        treasury_balance: economics.treasury.balance,
        next_event: economics.treasury.next_threshold
      }, ai_analysis)
      |> Map.merge(%{
        balanceProposals: Balance.proposals(),
        queuedEvents: length(queued)
      })

    GuardianMetrics.record_epoch(payload)
    Logger.info("[guardian] epoch #{epoch_no} result: severity=#{payload.severity}, anomalies=#{length(payload.anomalies || [])}")
    Logger.info("[guardian] SOUL supply: minted=#{payload.economy.totalSOULMinted}, burned=#{payload.economy.totalSOULBurned}, circulating=#{payload.economy.circulatingSOUL}")
    Logger.info("[guardian] Gini coefficient: #{payload.agents.wealthGini}")
    maybe_trigger_freeze(payload)
    next_state = maybe_emit_world_event(economics, payload, state)
    _ = Dashboard.write(payload)
    Phoenix.PubSub.broadcast(AFW.PubSub, "guardian", {:guardian_metrics, payload})
    schedule_epoch()
    {:noreply, %{next_state | epoch_events: [], mismatches: %{}}}
  end

  def handle_info({:reconciliation_mismatch, agent_id, on_chain, local}, state) do
    mismatches = Map.update(state.mismatches, agent_id, %{count: 1, on_chain: on_chain, local: local}, fn entry ->
      %{entry | count: entry.count + 1, on_chain: on_chain, local: local}
    end)

    {:noreply, %{state | mismatches: mismatches}}
  end

  def handle_info({:guardian_dashboard, _payload}, state) do
    {:noreply, state}
  end

  def handle_info({:guardian_metrics, _payload}, state) do
    {:noreply, state}
  end

  def handle_info(message, state) do
    next_state =
      case normalize_event(message) do
        nil -> state
        event -> %{state | epoch_events: [event | state.epoch_events] |> Enum.take(100)}
      end

    {:noreply, next_state}
  end

  defp schedule_epoch do
    Process.send_after(self(), :epoch, Application.get_env(:afw, :guardian_epoch_ms, 3_600_000))
  end

  defp brain_analysis(events, economics) do
    prompt = guardian_prompt(events, economics)

    case Interface.decide(%{analysis_type: :guardian, prompt: prompt, events: events, economics: economics}) do
      {:ok, payload} -> payload
      {:error, reason} ->
        Logger.warning("Guardian brain analysis fallback: #{inspect(reason)}")
        %{}
    end
  end

  defp guardian_prompt(events, economics) do
    """
    You are the Guardian Agent of Aethermoor.
    Analyze the following on-chain activity for the past epoch:
    #{Jason.encode!(%{events: events, economics: economics})}
    Detect anomalies: bot farming, exploits, unauthorized role grants, wash trading.
    Respond with: {anomalies, severity, proposed_action, evidence}
    """
  end

  defp maybe_trigger_freeze(%{severity: severity} = payload) when severity in ["high", "critical"] do
    wallet =
      payload.anomalies
      |> Enum.find_value(fn anomaly ->
        anomaly[:wallet] || anomaly["wallet"] || get_in(anomaly, [:details, :wallet]) || get_in(anomaly, ["details", "wallet"])
      end)

    if wallet, do: Proposer.submit_freeze_proposal(wallet, payload.evidence)
  end

  defp maybe_trigger_freeze(_payload), do: :ok

  defp maybe_emit_world_event(economics, payload, state) do
    balance = economics.treasury.balance

    triggered =
      cond do
        balance >= 10_000 * 1_000_000_000_000_000_000 -> "WORLD_BOSS"
        balance >= 5_000 * 1_000_000_000_000_000_000 -> "ZONE"
        balance >= 1_000 * 1_000_000_000_000_000_000 -> "MINI"
        true -> nil
      end

    if triggered && not Map.has_key?(state.world_events, triggered) do
      Hub.submit_event(%{
        type: :world_event,
        priority: :immediate,
        agent_id: 0,
        data: %{
          event_type: triggered,
          summary: "EventTreasury threshold reached: #{triggered}",
          balance: balance
        }
      })

      Phoenix.PubSub.broadcast(AFW.PubSub, "guardian", {:world_event_triggered, %{type: triggered, payload: payload}})
      %{state | world_events: Map.put(state.world_events, triggered, DateTime.utc_now())}
    else
      state
    end
  end

  defp mismatch_events(mismatches) do
    Enum.map(mismatches, fn {agent_id, entry} ->
      %{
        type: :reconciliation_mismatch,
        wallet: wallet_for_agent(agent_id),
        summary: "Repeated reconciliation mismatch for agent #{agent_id}",
        details: entry,
        severity: if(entry.count >= 2, do: "high", else: "medium")
      }
    end)
  end

  defp wallet_for_agent(agent_id) do
    Client.get_agent(agent_id)["observer"]
  rescue
    _ -> nil
  end

  defp normalize_event({:settlement_failed, agent_id, event_id, reason}) do
    %{type: :settlement_failed, agent_id: agent_id, summary: "Settlement #{event_id} failed", details: inspect(reason)}
  end

  defp normalize_event({:settlement_confirmed, agent_id, event_id, payload}) do
    %{type: :settlement_confirmed, agent_id: agent_id, summary: "Settlement #{event_id} confirmed", details: payload}
  end

  defp normalize_event({:world_event_triggered, payload}) do
    %{type: :world_event, summary: "Treasury threshold event triggered", details: payload}
  end

  defp normalize_event(_), do: nil
end
