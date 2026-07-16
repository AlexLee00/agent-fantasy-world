defmodule AFW.World.GridTest do
  use ExUnit.Case, async: true

  alias AFW.World.Grid

  test "TS-1: builds a 512x512 grid with more than 15% impassable tiles" do
    assert {512, 512} == Grid.dims()

    stats = Grid.stats()
    assert stats.total == 512 * 512
    assert stats.ratio > 0.15
  end

  test "map borders and out-of-bounds tiles are impassable" do
    refute Grid.passable?(0, 0)
    refute Grid.passable?(511, 511)
    refute Grid.passable?(-1, 10)
    refute Grid.passable?(10, 512)
  end

  test "regions: hub wins overlap, quadrants cover the continent" do
    assert Grid.region_at(256, 256) == 5
    assert Grid.region_at(210, 210) == 5
    assert Grid.region_at(20, 20) == 1
    assert Grid.region_at(490, 20) == 2
    assert Grid.region_at(20, 490) == 3
    assert Grid.region_at(490, 490) == 4
    assert Grid.region_name(5) == "Havenmoor"
  end

  test "every region spawn point is passable and inside its region" do
    for region_id <- 1..5 do
      {x, y} = Grid.spawn_point(region_id)
      assert Grid.passable?(x, y), "spawn for region #{region_id} not passable"
      assert Grid.region_at(x, y) == region_id
    end
  end

  test "random passable tiles stay inside the requested region" do
    :rand.seed(:exsss, {2026, 7, 16})

    for region_id <- 1..5, _attempt <- 1..20 do
      {x, y} = Grid.random_passable_tile(region_id)
      assert Grid.passable?(x, y)
      assert Grid.region_at(x, y) == region_id
    end
  end

  test "rivers block passage but bridges cross them" do
    # vertical river outside hub/bridges is water
    refute Grid.passable?(256, 100)
    # NW<->NE bridge span at y=125 crosses the vertical river
    assert Grid.passable?(256, 125)
    # NE<->SE bridge span at x=381 crosses the horizontal river
    assert Grid.passable?(381, 256)
  end
end
