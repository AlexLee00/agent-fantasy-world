defmodule AFW.World.Grid do
  @moduledoc """
  512x512 walkability bitmap plus terrain/region lookups for the Aethermoor
  open map (S1 M-1).

  The grid is derived from the Tiled map (`aethermoor_open.tmj`): the
  `collision` tile layer defines passability, `ground`+`terrain` define the
  terrain type byte, and the `regions`/`spawns` object layers define region
  rectangles (hub listed first, so it wins overlaps) and spawn points.

  `mix afw.build_grid` precomputes `priv/world/grid.bin`; at runtime the grid
  is loaded from that cache (when fresh) or rebuilt from the .tmj, then kept
  in `:persistent_term` for constant-time lookups.
  """

  @key {__MODULE__, :grid}

  ## Loading

  def load! do
    case :persistent_term.get(@key, nil) do
      nil ->
        grid = read_cached() || build!()
        :persistent_term.put(@key, grid)
        grid

      grid ->
        grid
    end
  end

  def build!, do: from_tmj(map_path())

  def rebuild! do
    grid = build!()
    :persistent_term.put(@key, grid)
    grid
  end

  def write_cache!(grid) do
    path = cache_path()
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, :erlang.term_to_binary(grid))
    path
  end

  def map_path do
    Application.get_env(:afw, :open_map_path) ||
      Path.join(:code.priv_dir(:afw), "static/assets/maps/aethermoor_open.tmj")
  end

  def cache_path do
    Application.get_env(:afw, :grid_cache_path) ||
      Path.join(:code.priv_dir(:afw), "world/grid.bin")
  end

  defp read_cached do
    with true <- File.exists?(cache_path()),
         {:ok, %{mtime: cache_time}} <- File.stat(cache_path()),
         {:ok, %{mtime: map_time}} <- File.stat(map_path()),
         true <- cache_time >= map_time do
      cache_path() |> File.read!() |> :erlang.binary_to_term()
    else
      _ -> nil
    end
  end

  ## Lookups (tile coordinates)

  def dims do
    grid = load!()
    {grid.width, grid.height}
  end

  def passable?(x, y) do
    grid = load!()

    x >= 0 and y >= 0 and x < grid.width and y < grid.height and
      bit(grid.pass, y * grid.width + x) == 1
  end

  def terrain_at(x, y) do
    grid = load!()

    if x >= 0 and y >= 0 and x < grid.width and y < grid.height do
      :binary.at(grid.terrain, y * grid.width + x)
    else
      0
    end
  end

  def region_at(x, y) do
    grid = load!()

    if x >= 0 and y >= 0 and x < grid.width and y < grid.height do
      :binary.at(grid.region, y * grid.width + x)
    else
      0
    end
  end

  def regions, do: load!().regions

  def region_name(region_id) do
    case Enum.find(load!().regions, &(&1.id == region_id)) do
      nil -> "Unknown"
      region -> region.name
    end
  end

  def spawn_point(region_id) do
    spawns = load!().spawns
    spawns[region_id] || spawns[5] || {256, 256}
  end

  @doc "Random passable tile inside a region (uses the caller's :rand state)."
  def random_passable_tile(region_id, attempts \\ 200) do
    grid = load!()

    case Enum.find(grid.regions, &(&1.id == region_id)) do
      nil ->
        spawn_point(region_id)

      region ->
        try_random_in_rect(region, region_id, attempts) || spawn_point(region_id)
    end
  end

  defp try_random_in_rect(_region, _region_id, 0), do: nil

  defp try_random_in_rect(region, region_id, attempts) do
    x = region.x + :rand.uniform(region.w) - 1
    y = region.y + :rand.uniform(region.h) - 1

    if region_at(x, y) == region_id and passable?(x, y) do
      {x, y}
    else
      try_random_in_rect(region, region_id, attempts - 1)
    end
  end

  @doc "Random passable tile within `radius` tiles of {x, y}, or nil."
  def random_passable_near(pos, radius, attempts \\ 30)

  def random_passable_near(_pos, _radius, 0), do: nil

  def random_passable_near({x, y} = pos, radius, attempts) do
    cx = x + :rand.uniform(radius * 2 + 1) - radius - 1
    cy = y + :rand.uniform(radius * 2 + 1) - radius - 1

    if {cx, cy} != pos and passable?(cx, cy) do
      {cx, cy}
    else
      random_passable_near(pos, radius, attempts - 1)
    end
  end

  def stats do
    grid = load!()
    total = grid.width * grid.height
    impassable = total - count_bits(grid.pass)
    %{total: total, impassable: impassable, ratio: impassable / total}
  end

  defp count_bits(bits) do
    for <<b::1 <- bits>>, reduce: 0 do
      acc -> acc + b
    end
  end

  defp bit(bits, index) do
    <<_::size(index), b::1, _::bitstring>> = bits
    b
  end

  ## Building from the Tiled map

  def from_tmj(path) do
    map = path |> File.read!() |> Jason.decode!()
    width = map["width"]
    height = map["height"]
    tile = map["tilewidth"]
    layers = Map.new(map["layers"], fn layer -> {layer["name"], layer} end)

    collision = decode_layer!(layers["collision"], width * height)
    ground = decode_layer!(layers["ground"], width * height)
    terrain = decode_layer!(layers["terrain"], width * height)

    regions = region_defs(layers["regions"], tile)
    spawns = spawn_defs(layers["spawns"], tile)

    pass =
      for <<gid::little-32 <- collision>>, into: <<>> do
        if gid == 0, do: <<1::1>>, else: <<0::1>>
      end

    terrain_bytes = combine_terrain(ground, terrain, [])
    region_bytes = region_bytes(regions, width, height)

    %{
      width: width,
      height: height,
      pass: pass,
      terrain: terrain_bytes,
      region: region_bytes,
      regions: regions,
      spawns: spawns
    }
  end

  defp decode_layer!(nil, _size), do: raise(ArgumentError, "missing tile layer in open map")

  defp decode_layer!(%{"encoding" => "base64", "data" => data}, size) do
    decoded = Base.decode64!(data)
    ^size = div(byte_size(decoded), 4)
    decoded
  end

  defp decode_layer!(%{"data" => data}, size) when is_list(data) and length(data) == size do
    IO.iodata_to_binary(Enum.map(data, fn gid -> <<gid::little-32>> end))
  end

  defp combine_terrain(<<>>, <<>>, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp combine_terrain(<<g::little-32, gr::binary>>, <<t::little-32, tr::binary>>, acc) do
    code = if t == 0, do: g, else: t
    combine_terrain(gr, tr, [<<min(code, 255)>> | acc])
  end

  defp region_bytes(regions, width, height) do
    for y <- 0..(height - 1), x <- 0..(width - 1), into: <<>> do
      <<region_for(regions, x, y)>>
    end
  end

  defp region_for(regions, x, y) do
    case Enum.find(regions, fn r -> x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h end) do
      nil -> 0
      region -> region.id
    end
  end

  defp region_defs(%{"objects" => objects}, tile) do
    Enum.map(objects, fn object ->
      %{
        id: object_property(object, "regionId"),
        name: object["name"],
        danger: object["type"],
        x: div(round(object["x"]), tile),
        y: div(round(object["y"]), tile),
        w: div(round(object["width"]), tile),
        h: div(round(object["height"]), tile)
      }
    end)
  end

  defp region_defs(_missing, _tile), do: []

  defp spawn_defs(%{"objects" => objects}, tile) do
    Map.new(objects, fn object ->
      region_id = object_property(object, "regionId")
      {region_id, {div(round(object["x"]), tile), div(round(object["y"]), tile)}}
    end)
  end

  defp spawn_defs(_missing, _tile), do: %{}

  defp object_property(object, name) do
    case Enum.find(object["properties"] || [], &(&1["name"] == name)) do
      nil -> 0
      property -> property["value"]
    end
  end
end
