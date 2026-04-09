defmodule AFW.Brain.Interface do
  @moduledoc "Behaviour for pluggable AFW brain providers."

  @callback decide(context :: map()) :: {:ok, map()} | {:error, term()}

  def decide(context) do
    provider_module()
    |> decide_with_fallback(context)
  end

  def provider_module do
    provider = Application.get_env(:afw, :brain_provider, "afw-basic")

    case provider do
      "afw-basic" -> AFW.Brain.AFWBasic
      "anthropic" -> AFW.Brain.Anthropic
      "openai" -> AFW.Brain.OpenAI
      "openclaw" -> AFW.Brain.OpenClaw
      "node" -> AFW.Brain.NodeProvider
      "claude-code" -> AFW.Brain.ClaudeCode
      _ -> tier_default(Application.get_env(:afw, :brain_tier, 1))
    end
  end

  def decide_with_fallback(module, context) do
    case module.decide(context) do
      {:ok, _} = ok -> ok
      {:error, _} when module != AFW.Brain.AFWBasic -> AFW.Brain.AFWBasic.decide(context)
      {:error, _} = error -> error
    end
  end

  defp tier_default(1), do: AFW.Brain.AFWBasic
  defp tier_default(2), do: AFW.Brain.Anthropic
  defp tier_default(3), do: AFW.Brain.OpenClaw
  defp tier_default(4), do: AFW.Brain.NodeProvider
  defp tier_default(_), do: AFW.Brain.AFWBasic
end
