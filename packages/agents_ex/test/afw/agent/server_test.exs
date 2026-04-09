defmodule AFW.Agent.ServerTest do
  use ExUnit.Case, async: true

  test "agent state struct can be initialized" do
    state = %AFW.Agent.State{
      agent_id: 1,
      class_id: 1,
      personality: [90, 10, 30, 80, 50],
      tick_interval: 10_000
    }

    assert state.agent_id == 1
    assert state.class_id == 1
  end
end
