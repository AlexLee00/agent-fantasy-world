defmodule AFW.Memory.Monologue do
  @moduledoc "Builds inspect-page monologues from durable agent memory."

  alias AFW.Memory.Store

  def for_agent(agent_id, agent_snapshot \\ %{}) do
    memories = Store.recent(agent_id, 12)
    reflection = Enum.find(memories, &(&1.type == :reflection))
    latest_action = Enum.find(memories, &(&1.type == :action))
    class_name = agent_snapshot["className"] || "adventurer"
    zone_name = agent_snapshot["zoneName"] || agent_snapshot["zone"] || "Aethermoor"

    cond do
      reflection ->
        "I am a #{class_name} moving through #{zone_name}. #{reflection.content}"

      latest_action ->
        "I am a #{class_name} in #{zone_name}. My latest memory is: #{latest_action.content}"

      true ->
        "I am a #{class_name} in #{zone_name}. I have no durable memories in this runtime yet."
    end
  end
end
