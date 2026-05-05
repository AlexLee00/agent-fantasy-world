defmodule AFW.Social.Dialogue do
  @moduledoc """
  Runtime dialogue transcript for Phase 1 social presentation.

  Dialogue is off-chain game state. It is kept in ETS for LiveView and persisted
  as JSONL for replay/debugging, while economic settlement remains on-chain.
  """

  use GenServer

  @table :afw_dialogue_transcript
  @max_entries 500

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    ensure_table!()
    path = Keyword.get(opts, :path, Application.get_env(:afw, :dialogue_log_path))
    prepare_path(path)
    {:ok, %{path: path}}
  end

  def record(agent_id, speaker, line, metadata \\ %{}) do
    ensure_table!()

    entry = %{
      id: System.system_time(:microsecond),
      agent_id: agent_id,
      speaker: speaker || "Agent ##{agent_id}",
      line: normalize_line(line),
      metadata: metadata || %{},
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    :ets.insert(@table, {entry.id, entry})
    prune()
    persist(entry)
    broadcast(entry)
    {:ok, entry}
  end

  def recent(limit \\ 20) do
    ensure_table!()

    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, entry} -> entry end)
    |> Enum.sort_by(& &1.id, :desc)
    |> Enum.take(limit)
  end

  def for_agent(agent_id, limit \\ 20) do
    recent(@max_entries)
    |> Enum.filter(&(&1.agent_id == agent_id))
    |> Enum.take(limit)
  end

  def clear_all do
    ensure_table!()
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def handle_cast({:persist, entry}, %{path: path} = state) do
    if usable_path?(path) do
      File.write(path, Jason.encode!(entry) <> "\n", [:append])
    end

    {:noreply, state}
  end

  defp persist(entry) do
    if Process.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, {:persist, entry})
    end
  end

  defp broadcast(entry) do
    if Process.whereis(AFW.PubSub) do
      Phoenix.PubSub.broadcast(AFW.PubSub, "dialogue", {:dialogue_recorded, entry})
    end
  end

  defp prune do
    overflow =
      @table
      |> :ets.tab2list()
      |> Enum.sort_by(fn {id, _entry} -> id end, :desc)
      |> Enum.drop(@max_entries)

    Enum.each(overflow, fn {id, _entry} -> :ets.delete(@table, id) end)
  end

  defp normalize_line(line) do
    line
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "..."
      value -> String.slice(value, 0, 220)
    end
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        @table
    end
  end

  defp prepare_path(path) do
    if usable_path?(path), do: File.mkdir_p!(Path.dirname(path))
  end

  defp usable_path?(path), do: is_binary(path) and String.trim(path) != ""
end
