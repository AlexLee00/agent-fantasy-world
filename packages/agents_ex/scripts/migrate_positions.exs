# migrate_positions.exs — S1 M-6: one-off migration of on-chain agents from
# legacy zone-jump positions to open-map tile spawns.
#
# For every on-chain agent, picks a deterministic random passable tile inside
# the region matching its current zoneId (zone_id == region_id) and writes:
#   priv/world/agent_positions.json          (consumed by AFW.Agent.Movement)
#   logs/migrate_positions_<utc>.json        (audit log, TS-4 evidence)
#
# Usage:
#   AFW_DISABLE_BOOT_AGENTS=1 AFW_DISABLE_ENDPOINT=1 \
#     mix run scripts/migrate_positions.exs
#
# Read-only on-chain; reruns are deterministic per agent.

alias AFW.Agent.Movement
alias AFW.Chain.Reader
alias AFW.World.Grid

Grid.load!()

total = Reader.call_uint(:agent_registry, "totalAgents", [])
IO.puts("agents on-chain: #{total}")

agent_ids = if total == 0, do: [], else: Enum.to_list(1..total)

{positions, log_entries} =
  Enum.reduce(agent_ids, {%{}, []}, fn agent_id, {positions, log_entries} ->
    try do
      agent = Reader.get_agent(agent_id)
      zone_id = agent["zoneId"]
      region = if zone_id in 1..5, do: zone_id, else: 1

      :rand.seed(:exsss, {agent_id, 2026, 716})
      {x, y} = Grid.random_passable_tile(region)

      entry = %{
        agent_id: agent_id,
        from_zone: zone_id,
        region: region,
        pos: [x, y],
        passable: Grid.passable?(x, y),
        region_ok: Grid.region_at(x, y) == region
      }

      {Map.put(positions, Integer.to_string(agent_id), [x, y]), [entry | log_entries]}
    rescue
      error ->
        entry = %{agent_id: agent_id, error: Exception.message(error)}
        {positions, [entry | log_entries]}
    end
  end)

log_entries = Enum.reverse(log_entries)

positions_path = Movement.positions_path()
File.mkdir_p!(Path.dirname(positions_path))
File.write!(positions_path, Jason.encode!(positions, pretty: true))
Movement.reload_positions()

timestamp =
  DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[:.]/, "-")

log_path = Path.join(File.cwd!(), "logs/migrate_positions_#{timestamp}.json")
File.mkdir_p!(Path.dirname(log_path))

File.write!(
  log_path,
  Jason.encode!(
    %{generated_at: timestamp, total_agents: total, entries: log_entries},
    pretty: true
  )
)

failures =
  Enum.count(log_entries, fn entry ->
    Map.has_key?(entry, :error) or not (entry.passable and entry.region_ok)
  end)

IO.puts("migrated #{map_size(positions)}/#{total} agents -> #{positions_path}")
IO.puts("log: #{log_path}")
IO.puts("failures: #{failures}")

if failures > 0 do
  IO.puts("TS-4 violated: some agents are not on a passable tile in their region")
  System.halt(1)
end
