# gen_openmap.exs — S1 M-2: deterministic generator for the Aethermoor open map.
#
# Produces:
#   priv/static/assets/maps/aethermoor_open.tmj   (512x512 Tiled JSON, base64 tile layers)
#   priv/static/assets/maps/placeholder_tiles.png (16-tile 32px placeholder tileset)
#
# Layout: central Havenmoor hub over the crossing of two rivers that split the
# continent into four regions (NW Lumenveil, NE Graymarch, SW Embervault,
# SE Voidreach). Regions connect through the hub and via four bridges.
# Usage: mix run --no-start scripts/gen_openmap.exs
# Output is deterministic — rerunning never changes committed artifacts.

defmodule AFW.Scripts.GenOpenMap do
  @moduledoc false

  @w 512
  @h 512
  @tile 32
  @border 6
  @hub_min 208
  @hub_max 303
  @river_min 248
  @river_max 263
  @bridge_spans [{124, 127}, {380, 383}]

  # tile gids (firstgid = 1), matching placeholder_tiles.png order
  @grass 1
  @marsh 2
  @volcanic 3
  @void_ground 4
  @plaza 5
  @road 6
  @bridge 7
  @water 8
  @mountain 9
  @forest 10
  @building 12

  # elliptical impassable mountain blobs {cx, cy, rx, ry}
  @mountains [
    {60, 150, 34, 18},
    {150, 60, 26, 14},
    {200, 180, 20, 12},
    {110, 220, 16, 10},
    {330, 90, 28, 15},
    {430, 160, 30, 17},
    {350, 200, 18, 11},
    {450, 60, 16, 10},
    {90, 330, 26, 16},
    {170, 430, 30, 15},
    {60, 470, 18, 10},
    {210, 350, 18, 11},
    {40, 300, 14, 9},
    {350, 350, 20, 12},
    {430, 320, 26, 15},
    {330, 450, 30, 16},
    {470, 380, 14, 9}
  ]

  @lakes [{60, 60, 18, 11}, {400, 70, 20, 12}, {70, 400, 20, 12}, {440, 440, 18, 11}]

  @forests [{190, 110, 24, 14}, {300, 150, 20, 12}, {140, 300, 22, 13}, {400, 420, 22, 13}]

  # hub buildings {x, y, w, h} in tiles — kept clear of the road cross (252..259)
  @buildings [
    {220, 220, 8, 6},
    {268, 220, 8, 6},
    {220, 270, 8, 6},
    {268, 270, 8, 6},
    {236, 212, 8, 6},
    {236, 286, 8, 6},
    {212, 240, 6, 8},
    {288, 240, 6, 8}
  ]

  @spawns %{1 => {128, 128}, 2 => {384, 128}, 3 => {128, 384}, 4 => {384, 384}, 5 => {256, 256}}

  @region_meta %{
    1 => {"Lumenveil", "SAFE"},
    2 => {"Graymarch", "MEDIUM"},
    3 => {"Embervault", "DANGER"},
    4 => {"Voidreach", "EXTREME"},
    5 => {"Havenmoor", "HUB"}
  }

  def run do
    out_dir = Path.join(File.cwd!(), "priv/static/assets/maps")
    File.mkdir_p!(out_dir)

    cells = for y <- 0..(@h - 1), x <- 0..(@w - 1), do: cell(x, y)
    impassable = Enum.count(cells, fn {_, _, c} -> c != 0 end)
    pct = Float.round(impassable * 100 / (@w * @h), 2)

    Enum.each(@spawns, fn {region, {x, y}} ->
      {_, _, c} = Enum.at(cells, y * @w + x)
      if c != 0, do: raise("spawn for region #{region} at #{x},#{y} is not passable")
    end)

    File.write!(Path.join(out_dir, "aethermoor_open.tmj"), Jason.encode!(tmj(cells)))
    File.write!(Path.join(out_dir, "placeholder_tiles.png"), png())

    IO.puts("aethermoor_open.tmj written: #{@w}x#{@h}, impassable #{impassable} (#{pct}%)")
    if pct <= 15.0, do: raise("TS-1 violated: impassable ratio #{pct}% is not > 15%")
  end

  # returns {ground_gid, terrain_gid, collision_gid} — collision != 0 means impassable
  defp cell(x, y) do
    region = region(x, y)

    cond do
      border?(x, y) -> {ground_for(region), @mountain, @mountain}
      region == 5 -> hub_cell(x, y)
      bridge?(x, y) -> {@bridge, 0, 0}
      river?(x, y) -> {@water, 0, @water}
      in_any?(x, y, @lakes) -> {@water, 0, @water}
      in_any?(x, y, @mountains) -> {ground_for(region), @mountain, @mountain}
      in_any?(x, y, @forests) -> {ground_for(region), @forest, 0}
      scatter_forest?(x, y) -> {ground_for(region), @forest, 0}
      true -> {ground_for(region), 0, 0}
    end
  end

  defp hub_cell(x, y) do
    in_building? =
      Enum.any?(@buildings, fn {bx, by, w, h} ->
        x >= bx and x < bx + w and y >= by and y < by + h
      end)

    cond do
      in_building? -> {@plaza, @building, @mountain}
      x in 252..259 or y in 252..259 -> {@road, 0, 0}
      true -> {@plaza, 0, 0}
    end
  end

  defp border?(x, y), do: x < @border or y < @border or x >= @w - @border or y >= @h - @border

  defp region(x, y) do
    cond do
      x >= @hub_min and x <= @hub_max and y >= @hub_min and y <= @hub_max -> 5
      x < 256 and y < 256 -> 1
      y < 256 -> 2
      x < 256 -> 3
      true -> 4
    end
  end

  defp river?(x, y), do: x in @river_min..@river_max or y in @river_min..@river_max

  defp bridge?(x, y) do
    (x in @river_min..@river_max and span?(y)) or
      (y in @river_min..@river_max and span?(x))
  end

  defp span?(v), do: Enum.any?(@bridge_spans, fn {a, b} -> v >= a and v <= b end)

  defp in_any?(x, y, blobs) do
    Enum.any?(blobs, fn {cx, cy, rx, ry} ->
      dx = (x - cx) / rx
      dy = (y - cy) / ry
      dx * dx + dy * dy <= 1.0
    end)
  end

  defp scatter_forest?(x, y), do: rem(:erlang.phash2({x, y, :forest}), 100) < 4

  defp ground_for(1), do: @grass
  defp ground_for(2), do: @marsh
  defp ground_for(3), do: @volcanic
  defp ground_for(4), do: @void_ground
  defp ground_for(5), do: @plaza

  defp tmj(cells) do
    %{
      "type" => "map",
      "version" => "1.10",
      "tiledversion" => "1.11.2",
      "orientation" => "orthogonal",
      "renderorder" => "right-down",
      "infinite" => false,
      "width" => @w,
      "height" => @h,
      "tilewidth" => @tile,
      "tileheight" => @tile,
      "nextlayerid" => 6,
      "nextobjectid" => 11,
      "tilesets" => [
        %{
          "firstgid" => 1,
          "name" => "placeholder",
          "image" => "placeholder_tiles.png",
          "imagewidth" => 128,
          "imageheight" => 128,
          "tilewidth" => @tile,
          "tileheight" => @tile,
          "tilecount" => 16,
          "columns" => 4,
          "margin" => 0,
          "spacing" => 0
        }
      ],
      "layers" => [
        tile_layer(1, "ground", cells, fn {g, _, _} -> g end),
        tile_layer(2, "terrain", cells, fn {_, t, _} -> t end),
        tile_layer(3, "collision", cells, fn {_, _, c} -> c end),
        regions_layer(4),
        spawns_layer(5)
      ]
    }
  end

  defp tile_layer(id, name, cells, pick) do
    data = cells |> Enum.map(fn cell -> <<pick.(cell)::little-32>> end) |> IO.iodata_to_binary()

    %{
      "id" => id,
      "name" => name,
      "type" => "tilelayer",
      "visible" => name != "collision",
      "opacity" => 1,
      "x" => 0,
      "y" => 0,
      "width" => @w,
      "height" => @h,
      "encoding" => "base64",
      "data" => Base.encode64(data)
    }
  end

  defp regions_layer(id) do
    rects = %{
      1 => {0, 0, 256, 256},
      2 => {256, 0, 256, 256},
      3 => {0, 256, 256, 256},
      4 => {256, 256, 256, 256},
      5 => {@hub_min, @hub_min, 96, 96}
    }

    objects =
      [5, 1, 2, 3, 4]
      |> Enum.with_index(1)
      |> Enum.map(fn {region, idx} ->
        {name, danger} = @region_meta[region]
        {x, y, w, h} = rects[region]

        %{
          "id" => idx,
          "name" => name,
          "type" => danger,
          "x" => x * @tile,
          "y" => y * @tile,
          "width" => w * @tile,
          "height" => h * @tile,
          "properties" => [%{"name" => "regionId", "type" => "int", "value" => region}]
        }
      end)

    %{
      "id" => id,
      "name" => "regions",
      "type" => "objectgroup",
      "visible" => true,
      "opacity" => 1,
      "draworder" => "topdown",
      "objects" => objects
    }
  end

  defp spawns_layer(id) do
    objects =
      @spawns
      |> Enum.sort()
      |> Enum.with_index(6)
      |> Enum.map(fn {{region, {x, y}}, idx} ->
        {name, _danger} = @region_meta[region]

        %{
          "id" => idx,
          "name" => "spawn_" <> String.downcase(name),
          "type" => "SPAWN",
          "point" => true,
          "x" => x * @tile + 16,
          "y" => y * @tile + 16,
          "properties" => [%{"name" => "regionId", "type" => "int", "value" => region}]
        }
      end)

    %{
      "id" => id,
      "name" => "spawns",
      "type" => "objectgroup",
      "visible" => true,
      "opacity" => 1,
      "draworder" => "topdown",
      "objects" => objects
    }
  end

  # 16 solid 32px tiles on a 4x4 sheet (RGB8), 1px darker edge per tile
  @colors [
    {106, 168, 79},
    {94, 125, 107},
    {140, 74, 60},
    {74, 59, 102},
    {201, 178, 133},
    {169, 143, 107},
    {139, 107, 71},
    {61, 110, 158},
    {110, 110, 110},
    {62, 112, 66},
    {131, 120, 106},
    {122, 85, 64},
    {40, 40, 40},
    {60, 60, 60},
    {80, 80, 80},
    {100, 100, 100}
  ]

  defp png do
    rows =
      for py <- 0..127 do
        pixels =
          for px <- 0..127, into: <<>> do
            {r, g, b} = Enum.at(@colors, div(py, 32) * 4 + div(px, 32))

            if rem(px, 32) in [0, 31] or rem(py, 32) in [0, 31] do
              <<max(r - 28, 0), max(g - 28, 0), max(b - 28, 0)>>
            else
              <<r, g, b>>
            end
          end

        <<0, pixels::binary>>
      end

    raw = IO.iodata_to_binary(rows)
    ihdr = <<128::32, 128::32, 8, 2, 0, 0, 0>>
    sig = <<137, 80, 78, 71, 13, 10, 26, 10>>

    IO.iodata_to_binary([
      sig,
      chunk("IHDR", ihdr),
      chunk("IDAT", :zlib.compress(raw)),
      chunk("IEND", <<>>)
    ])
  end

  defp chunk(type, data) do
    payload = type <> data
    <<byte_size(data)::32, payload::binary, :erlang.crc32(payload)::32>>
  end
end

AFW.Scripts.GenOpenMap.run()
