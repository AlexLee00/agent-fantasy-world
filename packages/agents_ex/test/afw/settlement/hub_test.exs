defmodule AFW.Settlement.HubTest do
  use ExUnit.Case, async: false

  alias AFW.Settlement.{Hub, State}

  setup do
    unless Process.whereis(AFW.PubSub), do: start_supervised!({Phoenix.PubSub, name: AFW.PubSub})
    unless Process.whereis(Hub), do: start_supervised!(Hub)
    State.ensure_tables!()
    State.correct_confirmed(22, 100)
    :ok
  end

  test "submit_event updates optimistic display and queue" do
    Hub.submit_event(%{
      type: :npc_purchase,
      priority: :normal,
      agent_id: 22,
      data: %{
        soul_changes: [%{agent_id: 22, delta: -5}],
        state_changes: [%{agent_id: 22, field: :statusName, value: "RESTING"}],
        summary: "REST tavern -> -5 SOUL"
      }
    })

    Process.sleep(50)

    assert [%{agent_id: 22, type: :npc_purchase}] = Hub.queued_events()
    assert 95 == State.spendable_soul(22)
    assert {95, -5} == State.display_soul(22)
    assert "RESTING" == State.optimistic_state(22).offchain["statusName"]
  end
end
