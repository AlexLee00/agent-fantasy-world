defmodule AFW.World.Pathfinder do
  @moduledoc """
  A* pathfinding over `AFW.World.Grid` with an ETS path cache (S1 M-3).

  Paths are 4-directional lists of tiles from just after the start tile up to
  and including the goal. Results are cached by {from, to}; the cache is
  cleared wholesale when it grows past the cap (paths are cheap to recompute).
  """

  alias AFW.World.Grid

  @cache :afw_path_cache
  @max_cache_entries 5_000
  @max_nodes 20_000
  @infinity 1_000_000_000

  def find_path(from, to, opts \\ [])

  def find_path(from, from, _opts), do: {:ok, []}

  def find_path({fx, fy} = from, {tx, ty} = to, opts) do
    cond do
      not Grid.passable?(fx, fy) ->
        {:error, :invalid_start}

      not Grid.passable?(tx, ty) ->
        {:error, :invalid_goal}

      true ->
        cached(from, to) || compute(from, to, opts)
    end
  end

  def cache_size do
    ensure_cache!()
    :ets.info(@cache, :size)
  end

  def clear_cache do
    ensure_cache!()
    :ets.delete_all_objects(@cache)
    :ok
  end

  defp cached(from, to) do
    ensure_cache!()

    case :ets.lookup(@cache, {from, to}) do
      [{_key, path}] -> {:ok, path}
      [] -> nil
    end
  end

  defp compute(from, to, opts) do
    max_nodes = Keyword.get(opts, :max_nodes, @max_nodes)

    open = :gb_sets.singleton({heuristic(from, to), from})
    g = %{from => 0}

    case astar(open, g, %{}, MapSet.new(), to, 0, max_nodes) do
      {:ok, path} ->
        put_cache(from, to, path)
        {:ok, path}

      error ->
        error
    end
  end

  defp put_cache(from, to, path) do
    ensure_cache!()

    if :ets.info(@cache, :size) >= @max_cache_entries do
      :ets.delete_all_objects(@cache)
    end

    :ets.insert(@cache, {{from, to}, path})
  end

  defp astar(open, g, came, closed, goal, expanded, max_nodes) do
    if :gb_sets.is_empty(open) do
      {:error, :unreachable}
    else
      {{_f, pos}, open} = :gb_sets.take_smallest(open)

      cond do
        pos == goal ->
          {:ok, reconstruct(came, goal, [])}

        MapSet.member?(closed, pos) ->
          astar(open, g, came, closed, goal, expanded, max_nodes)

        expanded >= max_nodes ->
          {:error, :unreachable}

        true ->
          closed = MapSet.put(closed, pos)
          base_g = Map.fetch!(g, pos)

          {open, g, came} =
            Enum.reduce(neighbors(pos), {open, g, came}, fn {nx, ny} = next, {o, gm, cm} ->
              tentative = base_g + 1

              if Grid.passable?(nx, ny) and not MapSet.member?(closed, next) and
                   tentative < Map.get(gm, next, @infinity) do
                {
                  :gb_sets.add({tentative + heuristic(next, goal), next}, o),
                  Map.put(gm, next, tentative),
                  Map.put(cm, next, pos)
                }
              else
                {o, gm, cm}
              end
            end)

          astar(open, g, came, closed, goal, expanded + 1, max_nodes)
      end
    end
  end

  defp reconstruct(came, pos, acc) do
    case Map.fetch(came, pos) do
      {:ok, previous} -> reconstruct(came, previous, [pos | acc])
      :error -> acc
    end
  end

  defp neighbors({x, y}), do: [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]

  defp heuristic({x1, y1}, {x2, y2}), do: abs(x1 - x2) + abs(y1 - y2)

  defp ensure_cache! do
    case :ets.whereis(@cache) do
      :undefined ->
        :ets.new(@cache, [:named_table, :public, :set, read_concurrency: true])

      _ ->
        @cache
    end
  rescue
    ArgumentError -> @cache
  end
end
