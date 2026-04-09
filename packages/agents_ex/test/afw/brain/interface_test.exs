defmodule AFW.Brain.InterfaceTest do
  use ExUnit.Case, async: false

  setup do
    original = Application.get_env(:afw, :brain_provider)
    on_exit(fn -> Application.put_env(:afw, :brain_provider, original) end)
    :ok
  end

  test "falls back to AFW basic when selected provider fails" do
    Application.put_env(:afw, :brain_provider, "node")

    assert {:ok, %{"action" => action}} =
             AFW.Brain.Interface.decide(%{
               prompt: "test",
               event: %AFW.World.Event{type: :explore, target: "path"}
             })

    assert action in ["EXPLORE", "REST", "TRADE", "FIGHT", "TALK"]
  end
end
