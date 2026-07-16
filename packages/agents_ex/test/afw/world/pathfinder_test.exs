defmodule AFW.World.PathfinderTest do
  use ExUnit.Case, async: true

  alias AFW.World.{Grid, Pathfinder}

  test "TS-2: paths exist from the hub to every region spawn" do
    hub = Grid.spawn_point(5)

    for region_id <- 1..4 do
      dest = Grid.spawn_point(region_id)
      assert {:ok, path} = Pathfinder.find_path(hub, dest)
      assert List.last(path) == dest
      assert_valid_path(hub, path)
    end
  end

  test "TS-2: never routes through walls; every step is 4-adjacent" do
    :rand.seed(:exsss, {1, 2, 3})
    from = Grid.spawn_point(1)

    for _attempt <- 1..25 do
      to = Grid.random_passable_near(from, 30) || from

      case Pathfinder.find_path(from, to) do
        {:ok, path} -> assert_valid_path(from, path)
        {:error, reason} -> assert reason == :unreachable
      end
    end
  end

  test "rejects impassable start or goal tiles" do
    assert {:error, :invalid_start} = Pathfinder.find_path({0, 0}, {128, 128})
    assert {:error, :invalid_goal} = Pathfinder.find_path({128, 128}, {0, 0})
  end

  test "TS-2: 1000 pathfinding calls average under 5ms" do
    :rand.seed(:exsss, {2026, 7, 16})
    Pathfinder.clear_cache()
    origins = for region_id <- 1..5, do: Grid.spawn_point(region_id)

    pairs =
      for i <- 1..1000 do
        from = Enum.at(origins, rem(i, 5))
        {from, Grid.random_passable_near(from, 30) || from}
      end

    {micros, :ok} =
      :timer.tc(fn ->
        Enum.each(pairs, fn {from, to} -> Pathfinder.find_path(from, to) end)
      end)

    average_ms = micros / 1000 / 1000
    assert average_ms < 5.0, "average #{Float.round(average_ms, 3)}ms is not < 5ms"
  end

  defp assert_valid_path(from, path) do
    Enum.reduce(path, from, fn {x, y} = step, {px, py} ->
      assert Grid.passable?(x, y)
      assert abs(x - px) + abs(y - py) == 1
      step
    end)
  end
end
