defmodule AFW.Brain.AFWBasic do
  @moduledoc "Tier 1 free fallback provider with a lightweight heuristic/API-backed brain."
  @behaviour AFW.Brain.Interface

  def decide(%{prompt: prompt, event: event}) do
    api_key = Application.get_env(:afw, :afw_basic_api_key, "")

    if api_key == "" do
      {:ok, heuristic_decision(event)}
    else
      response =
        Req.post(
          "https://api.openai.com/v1/chat/completions",
          headers: [
            {"authorization", "Bearer " <> api_key},
            {"content-type", "application/json"}
          ],
          json: %{
            model: "gpt-4.1-mini",
            max_tokens: 120,
            messages: [%{role: "user", content: String.slice(prompt, 0, 2_000)}],
            response_format: %{type: "json_object"}
          }
        )

      with {:ok, %{status: 200, body: body}} <- response,
           [%{"message" => %{"content" => content}} | _] <- body["choices"],
           {:ok, action} <- Jason.decode(content) do
        {:ok, action}
      else
        _ -> {:ok, heuristic_decision(event)}
      end
    end
  end

  def decide(%{analysis_type: :guardian, events: events, economics: economics}) do
    severity =
      cond do
        Enum.any?(events, &(&1.type in [:unauthorized_role_grant, :unauthorized_mint])) ->
          "critical"

        Enum.any?(events, &(&1.type in [:duplicate_reward, :wash_trade])) ->
          "high"

        economics.wealth.gini > 0.5 ->
          "medium"

        true ->
          "low"
      end

    anomalies =
      Enum.map(events, fn event ->
        %{
          pattern: event.type,
          wallet: event[:wallet] || get_in(event, [:data, :wallet]),
          summary: event[:summary] || get_in(event, [:data, :summary]) || "observed"
        }
      end)

    {:ok,
     %{
       "anomalies" => anomalies,
       "severity" => severity,
       "proposed_action" =>
         if(severity in ["high", "critical"], do: "PROPOSE_FREEZE", else: "OBSERVE"),
       "evidence" => %{
         "events" => length(events),
         "gini" => economics.wealth.gini,
         "inflationRate" => economics.soul.inflation_rate
       }
     }}
  end

  defp heuristic_decision(%{type: :survival}), do: %{"action" => "REST", "confidence" => 0.95}
  defp heuristic_decision(%{type: :trade}), do: %{"action" => "TRADE", "confidence" => 0.75}

  defp heuristic_decision(%{type: :npc, target: target}),
    do: %{"action" => "TALK", "target" => target, "confidence" => 0.7}

  defp heuristic_decision(%{type: :monster, target: target}),
    do: %{"action" => "FIGHT", "target" => target, "confidence" => 0.6}

  defp heuristic_decision(%{target: target}),
    do: %{"action" => "EXPLORE", "target" => target, "confidence" => 0.6}
end
