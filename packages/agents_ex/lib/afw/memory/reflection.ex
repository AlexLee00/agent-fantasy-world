defmodule AFW.Memory.Reflection do
  @moduledoc "Creates compact periodic reflections from an agent's memory stream."

  alias AFW.Memory.Store

  def reflect(agent_id, tick \\ nil) do
    memories = Store.recent(agent_id, 30)

    case Enum.reject(memories, &(&1.type == :reflection)) do
      [] ->
        :noop

      action_memories ->
        summary = build_summary(action_memories)

        Store.record(agent_id, :reflection, summary, %{
          tick: tick,
          source_count: length(action_memories)
        })
    end
  end

  defp build_summary(memories) do
    action_counts =
      memories
      |> Enum.map(&get_in(&1, [:metadata, :action]))
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_action, count} -> count end, :desc)
      |> Enum.map(fn {action, count} -> "#{action}=#{count}" end)
      |> Enum.join(", ")

    latest =
      memories
      |> Enum.take(3)
      |> Enum.map(& &1.content)
      |> Enum.join(" | ")

    "Recent pattern: #{blank_as_none(action_counts)}. Latest memories: #{blank_as_none(latest)}."
  end

  defp blank_as_none(""), do: "none"
  defp blank_as_none(value), do: value
end
