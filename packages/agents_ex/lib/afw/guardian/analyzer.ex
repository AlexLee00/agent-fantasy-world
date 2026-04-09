defmodule AFW.Guardian.Analyzer do
  @moduledoc "Computes security and economic analytics for Guardian Agent."

  def analyze(events, metrics, ai_analysis \\ %{}) do
    anomalies = heuristic_anomalies(events) ++ normalize_ai_anomalies(ai_analysis)
    severity = ai_analysis["severity"] || ai_analysis[:severity] || heuristic_severity(anomalies, metrics)
    proposed_action = ai_analysis["proposed_action"] || ai_analysis[:proposed_action] || proposed_action(severity)

    %{
      timestamp: DateTime.utc_now(),
      economy: %{
        totalSOULMinted: metrics[:total_minted] || get_in(metrics, [:soul, :total_minted]) || 0,
        totalSOULBurned: metrics[:total_burned] || get_in(metrics, [:soul, :total_burned]) || 0,
        circulatingSOUL: metrics[:total_supply] || get_in(metrics, [:soul, :circulating]) || 0,
        inflationRate: metrics[:inflation_rate] || get_in(metrics, [:soul, :inflation_rate]) || inflation(metrics)
      },
      agents: %{
        totalActive: metrics[:agent_count] || 0,
        averageLevel: metrics[:average_level] || 0,
        wealthGini: metrics[:wealth_gini] || get_in(metrics, [:wealth, :gini]) || 0
      },
      combat: %{
        totalFights: metrics[:combat_count] || get_in(metrics, [:combat, :total_fights]) || 0,
        agentWinRate: metrics[:agent_win_rate] || get_in(metrics, [:combat, :win_rate]) || 0,
        totalDeaths: metrics[:death_count] || 0
      },
      treasury: %{
        balance: metrics[:treasury_balance] || get_in(metrics, [:treasury, :balance]) || 0,
        nextEvent: metrics[:next_event] || get_in(metrics, [:treasury, :next_threshold]) || "MINI at 1000",
        remainingToNext: get_in(metrics, [:treasury, :remaining_to_next]) || 0
      },
      anomalies: anomalies,
      severity: severity,
      proposedAction: proposed_action,
      evidence: ai_analysis["evidence"] || ai_analysis[:evidence] || %{}
    }
  end

  defp inflation(metrics) do
    minted = max(metrics[:total_minted] || get_in(metrics, [:soul, :total_minted]) || 0, 1)
    ((metrics[:total_minted] || get_in(metrics, [:soul, :total_minted]) || 0) - (metrics[:total_burned] || get_in(metrics, [:soul, :total_burned]) || 0)) / minted
  end

  defp heuristic_anomalies(events) do
    Enum.flat_map(events, fn event ->
      cond do
        event.type in [:unauthorized_mint, :unauthorized_role_grant] ->
          [%{severity: "critical", pattern: String.upcase(to_string(event.type)), details: event}]

        event.type in [:duplicate_reward, :wash_trade, :reconciliation_mismatch] ->
          [%{severity: "high", pattern: String.upcase(to_string(event.type)), details: event}]

        true ->
          []
      end
    end)
  end

  defp normalize_ai_anomalies(ai_analysis) do
    ai_analysis["anomalies"] || ai_analysis[:anomalies] || []
  end

  defp heuristic_severity(anomalies, metrics) do
    cond do
      Enum.any?(anomalies, &((Map.get(&1, :severity) || Map.get(&1, "severity")) in ["critical"])) -> "critical"
      Enum.any?(anomalies, &((Map.get(&1, :severity) || Map.get(&1, "severity")) in ["high"])) -> "high"
      (metrics[:wealth_gini] || get_in(metrics, [:wealth, :gini]) || 0) > 0.5 -> "medium"
      true -> "low"
    end
  end

  defp proposed_action(severity) when severity in ["high", "critical"], do: "PROPOSE_FREEZE"
  defp proposed_action("medium"), do: "WARN"
  defp proposed_action(_), do: "OBSERVE"
end
