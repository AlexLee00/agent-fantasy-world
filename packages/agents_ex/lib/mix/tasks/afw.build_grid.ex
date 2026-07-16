defmodule Mix.Tasks.Afw.BuildGrid do
  @shortdoc "Builds priv/world/grid.bin from the Aethermoor open map (S1 M-1)"

  @moduledoc """
  Reads `priv/static/assets/maps/aethermoor_open.tmj` and precomputes the
  walkability/terrain/region grid used by `AFW.World.Grid`, writing it to
  `priv/world/grid.bin`. Fails when the impassable ratio is not > 15% (TS-1).

      mix afw.build_grid
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")

    grid = AFW.World.Grid.from_tmj(AFW.World.Grid.map_path())
    path = AFW.World.Grid.write_cache!(grid)

    total = grid.width * grid.height
    passable = for <<b::1 <- grid.pass>>, reduce: 0, do: (acc -> acc + b)
    impassable = total - passable
    pct = Float.round(impassable * 100 / total, 2)

    region_counts =
      grid.region |> :binary.bin_to_list() |> Enum.frequencies() |> Enum.sort()

    Mix.shell().info("grid: #{grid.width}x#{grid.height} -> #{path}")
    Mix.shell().info("impassable: #{impassable}/#{total} (#{pct}%)")

    Enum.each(region_counts, fn {region_id, count} ->
      name = Enum.find(grid.regions, %{name: "?"}, &(&1.id == region_id)).name || "?"
      Mix.shell().info("region #{region_id} #{name}: #{count} tiles")
    end)

    Enum.each(grid.spawns, fn {region_id, {x, y}} ->
      Mix.shell().info("spawn region #{region_id}: {#{x}, #{y}}")
    end)

    if pct <= 15.0 do
      Mix.raise("TS-1 violated: impassable ratio #{pct}% is not > 15%")
    end
  end
end
