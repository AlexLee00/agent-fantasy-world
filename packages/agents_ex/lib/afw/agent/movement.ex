defmodule AFW.Agent.Movement do
  @moduledoc """
  Tile-based movement for agents on the Aethermoor open map (S1 M-3/M-4).

  Each tick the agent advances along an A* path by its class movement
  allowance (3-5 tiles). Crossing a region boundary submits a
  `:region_transition` settlement event with BATCH priority — the only
  on-chain footprint of movement; same-region steps stay off-chain.
  """

  alias AFW.Settlement.Hub
  alias AFW.World.{Grid, Pathfinder}

  # tiles per tick by class (WARRIOR/MAGE/RANGER/HEALER/TANK)
  @speed %{1 => 4, 2 => 3, 3 => 5, 4 => 3, 5 => 3}
  @default_speed 3
  @explore_radius 30
  @local_radius 10
  @positions_key {__MODULE__, :migrated_positions}

  @doc """
  Advances one tick of movement. Returns a map with :pos, :dest, :path,
  :region and :transition (nil or %{from: r, to: r}).
  """
  def step(state, context, action) do
    pos = state.pos || initial_pos(state, context)
    {dest, path} = ensure_path(state, pos, action)

    speed = Map.get(@speed, state.class_id, @default_speed)
    {new_pos, remaining} = advance(pos, path, speed)

    from_region = region_of(pos)
    to_region = region_of(new_pos)

    transition =
      if from_region != to_region and to_region > 0 do
        submit_transition(state.agent_id, from_region, to_region)
        %{from: from_region, to: to_region}
      end

    %{
      pos: new_pos,
      dest: if(new_pos == dest, do: nil, else: dest),
      path: remaining,
      region: to_region,
      transition: transition
    }
  end

  @doc "Initial tile for an agent: migrated position, else its region's spawn."
  def initial_pos(state, context) do
    migrated_position(state.agent_id) ||
      Grid.spawn_point(get_in(context, [:agent, "zoneId"]) || state.zone_id || 1)
  end

  @doc "Looks up a position produced by scripts/migrate_positions.exs, if any."
  def migrated_position(agent_id) do
    positions =
      case :persistent_term.get(@positions_key, nil) do
        nil ->
          positions = read_positions_file()
          :persistent_term.put(@positions_key, positions)
          positions

        positions ->
          positions
      end

    case positions[to_string(agent_id)] do
      [x, y] when is_integer(x) and is_integer(y) -> {x, y}
      _ -> nil
    end
  end

  @doc "Forces a re-read of the migrated positions file (used by scripts/tests)."
  def reload_positions do
    :persistent_term.put(@positions_key, read_positions_file())
    :ok
  end

  def positions_path do
    Application.get_env(:afw, :agent_positions_path) ||
      Path.join(:code.priv_dir(:afw), "world/agent_positions.json")
  end

  defp read_positions_file do
    with {:ok, body} <- File.read(positions_path()),
         {:ok, positions} when is_map(positions) <- Jason.decode(body) do
      positions
    else
      _ -> %{}
    end
  end

  defp ensure_path(%{path: [_ | _] = path, dest: dest}, _pos, _action) when not is_nil(dest) do
    {dest, path}
  end

  defp ensure_path(_state, pos, action), do: pick_path(pos, radius_for(action), 3)

  defp radius_for("EXPLORE"), do: @explore_radius
  defp radius_for(_action), do: @local_radius

  defp pick_path(_pos, _radius, 0), do: {nil, []}

  defp pick_path(pos, radius, attempts) do
    dest =
      Grid.random_passable_near(pos, radius) ||
        Grid.random_passable_tile(region_of(pos))

    case Pathfinder.find_path(pos, dest) do
      {:ok, path} -> {dest, path}
      {:error, _reason} -> pick_path(pos, radius, attempts - 1)
    end
  end

  defp advance(pos, [], _speed), do: {pos, []}

  defp advance(pos, path, speed) do
    steps = min(speed, length(path))
    {Enum.at(path, steps - 1) || pos, Enum.drop(path, steps)}
  end

  defp region_of({x, y}), do: Grid.region_at(x, y)

  defp submit_transition(agent_id, from_region, to_region) do
    Hub.submit_event(%{
      type: :region_transition,
      priority: :batch,
      agent_id: agent_id,
      data: %{
        agent_id: agent_id,
        from_region: from_region,
        to_region: to_region,
        zone_id: to_region,
        soul_changes: [],
        state_changes: [%{agent_id: agent_id, field: :zoneId, value: to_region}],
        summary:
          "MOVE #{Grid.region_name(from_region)} -> #{Grid.region_name(to_region)} " <>
            "(region #{from_region}->#{to_region})"
      }
    })
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end
end
