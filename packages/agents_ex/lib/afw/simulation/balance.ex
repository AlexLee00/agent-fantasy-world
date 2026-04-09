defmodule AFW.Simulation.Balance do
  @moduledoc "Generates balance proposals from long-running simulation metrics."

  alias AFW.Guardian.Economics
  alias AFW.Simulation.Metrics

  def proposals do
    metrics = Metrics.snapshot()
    economics = Economics.snapshot()

    []
    |> maybe_add(death_rate(metrics) > 0.3, "Monster ATK should be lowered by 10% because death rate exceeded 30%.")
    |> maybe_add(economics.wealth.gini > 0.5, "Combat reward floor should be raised because wealth inequality exceeded the target band.")
    |> maybe_add(economics.soul.inflation_rate > 0.05, "SOUL burn rate should be increased because epoch inflation exceeded 5%.")
  end

  def summary do
    %{
      generated_at: DateTime.utc_now(),
      proposals: proposals()
    }
  end

  defp death_rate(metrics) do
    deaths = metrics[:crashCount] || metrics["crashCount"] || 0
    total = max(metrics[:totalTicks] || metrics["totalTicks"] || 0, 1)
    deaths / total
  end

  defp maybe_add(list, true, proposal), do: list ++ [proposal]
  defp maybe_add(list, false, _proposal), do: list
end
