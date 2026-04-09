defmodule AFW.Guardian.Analyzer do
  @moduledoc "Computes security and economic analytics for Guardian Agent."

  def analyze(events, metrics) do
    anomalies =
      Enum.flat_map(events, fn event ->
        cond do
          event.type == :unauthorized_mint ->
            [%{severity: "high", pattern: "UNAUTHORIZED_MINT", details: event}]

          event.type == :duplicate_reward ->
            [%{severity: "high", pattern: "DUPLICATE_REWARD", details: event}]

          true ->
            []
        end
      end)

    %{
      timestamp: DateTime.utc_now(),
      economy: %{
        totalSOULMinted: metrics[:total_minted] || 0,
        totalSOULBurned: metrics[:total_burned] || 0,
        circulatingSOUL: metrics[:total_supply] || 0,
        inflationRate: inflation(metrics)
      },
      agents: %{
        totalActive: metrics[:agent_count] || 0,
        averageLevel: metrics[:average_level] || 0,
        wealthGini: metrics[:wealth_gini] || 0
      },
      combat: %{
        totalFights: metrics[:combat_count] || 0,
        agentWinRate: metrics[:agent_win_rate] || 0,
        totalDeaths: metrics[:death_count] || 0
      },
      treasury: %{
        balance: metrics[:treasury_balance] || 0,
        nextEvent: metrics[:next_event] || "MINI at 1000"
      },
      anomalies: anomalies
    }
  end

  defp inflation(metrics) do
    minted = max(metrics[:total_minted] || 0, 1)
    ((metrics[:total_minted] || 0) - (metrics[:total_burned] || 0)) / minted
  end
end
