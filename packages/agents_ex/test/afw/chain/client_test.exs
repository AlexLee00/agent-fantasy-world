defmodule AFW.Chain.ClientTest do
  use ExUnit.Case, async: true

  test "tracked contracts includes all deployed integrations" do
    tracked = AFW.Chain.Client.tracked_contracts()
    assert :agent_registry in tracked
    assert :combat_resolver in tracked
    assert :marketplace in tracked
    assert length(tracked) == 15
  end
end
