defmodule AFW.Guardian.AnalyzerTest do
  use ExUnit.Case, async: true

  test "produces a dashboard payload" do
    payload =
      AFW.Guardian.Analyzer.analyze([], %{
        total_minted: 1000,
        total_burned: 100,
        total_supply: 900,
        agent_count: 3,
        average_level: 2.0,
        wealth_gini: 0.33,
        combat_count: 10,
        agent_win_rate: 0.6,
        death_count: 4,
        treasury_balance: 50,
        next_event: "MINI at 1000"
      })

    assert payload.economy.totalSOULMinted == 1000
    assert payload.agents.totalActive == 3
    assert payload.treasury.nextEvent == "MINI at 1000"
  end
end
