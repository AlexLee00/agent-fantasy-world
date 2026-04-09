defmodule AFW.Simulation.BalanceTest do
  use ExUnit.Case, async: true

  test "summary returns proposal list" do
    summary = AFW.Simulation.Balance.summary()
    assert is_list(summary.proposals)
  end
end
