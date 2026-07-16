defmodule AFW.Agent.MovementTest do
  # sync + cleanup: region transitions submit real events into the global
  # settlement queue started by the application supervision tree.
  use ExUnit.Case, async: false

  alias AFW.Agent.Movement
  alias AFW.World.Grid

  @test_agent_id 990

  setup do
    on_exit(fn ->
      # barrier: submit_event is a cast — a synchronous call to the Hub
      # guarantees every in-flight cast has been processed before cleanup
      if Process.whereis(AFW.Settlement.Hub) do
        try do
          AFW.Settlement.Hub.queued_events()
        catch
          _, _ -> :ok
        end
      end

      case :ets.whereis(:event_queue) do
        :undefined ->
          :ok

        _table ->
          :event_queue
          |> :ets.tab2list()
          |> Enum.filter(fn {_key, event} -> event.agent_id == @test_agent_id end)
          |> Enum.each(fn {key, _event} -> :ets.delete(:event_queue, key) end)
      end
    end)

    :ok
  end

  defp state(pos, extra \\ %{}) do
    Map.merge(
      %{agent_id: @test_agent_id, class_id: 3, zone_id: 1, pos: pos, dest: nil, path: []},
      extra
    )
  end

  defp context, do: %{agent: %{"zoneId" => 1}}

  test "advances at most class speed tiles to a passable adjacent-connected tile" do
    :rand.seed(:exsss, {9, 9, 9})
    {sx, sy} = start = Grid.spawn_point(1)

    result = Movement.step(state(start), context(), "EXPLORE")

    {nx, ny} = result.pos
    assert Grid.passable?(nx, ny)
    # RANGER (class 3) moves at most 5 tiles per tick
    assert abs(nx - sx) + abs(ny - sy) <= 5
  end

  test "spawns at the region spawn point when the agent has no position yet" do
    :rand.seed(:exsss, {4, 4, 4})
    result = Movement.step(state(nil), context(), "EXPLORE")
    assert Grid.passable?(elem(result.pos, 0), elem(result.pos, 1))
  end

  test "M-4: crossing into the hub reports a region transition" do
    # x=207 is Lumenveil, x=208 is the first Havenmoor column
    from = {207, 230}
    to = {208, 230}
    assert Grid.passable?(207, 230) and Grid.passable?(208, 230)
    assert Grid.region_at(207, 230) == 1
    assert Grid.region_at(208, 230) == 5

    result = Movement.step(state(from, %{dest: to, path: [to]}), context(), "EXPLORE")

    assert result.pos == to
    assert result.region == 5
    assert result.transition == %{from: 1, to: 5}
  end

  test "M-4: movement inside one region reports no transition" do
    {sx, sy} = start = Grid.spawn_point(1)
    step_to = {sx + 1, sy}
    assert Grid.passable?(sx + 1, sy)

    result = Movement.step(state(start, %{dest: step_to, path: [step_to]}), context(), "TALK")

    assert result.pos == step_to
    assert result.transition == nil
  end
end
