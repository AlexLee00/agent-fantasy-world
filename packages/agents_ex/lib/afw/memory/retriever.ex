defmodule AFW.Memory.Retriever do
  @moduledoc "Builds lightweight memory recall queries for agent prompts."

  alias AFW.Memory.Store

  def relevant_for_context(context, event, limit \\ 5) do
    agent_id = get_in(context, [:agent, "agentId"])

    if agent_id do
      Store.relevant(agent_id, query(context, event), limit)
    else
      []
    end
  end

  defp query(context, event) do
    [
      get_in(context, [:zone, "name"]),
      event.type,
      event.target,
      event.summary,
      recent_actions(context)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp recent_actions(context) do
    context
    |> Map.get(:history, [])
    |> Enum.map(&Map.get(&1, :action))
    |> Enum.join(" ")
  end
end
