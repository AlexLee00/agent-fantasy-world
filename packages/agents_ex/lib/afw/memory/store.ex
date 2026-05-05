defmodule AFW.Memory.Store do
  @moduledoc """
  Agent memory stream backed by ETS with optional JSONL persistence.

  This is the Phase 1 memory baseline: fast local recall for prompts and
  inspect views, without introducing a database dependency before the visual
  prototype stabilizes.
  """

  use GenServer

  @table :afw_memory_store
  @max_per_agent 200

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    ensure_table!()
    path = Keyword.get(opts, :path, Application.get_env(:afw, :memory_log_path))
    prepare_path(path)
    {:ok, %{path: path}}
  end

  def record(agent_id, type, content, metadata \\ %{}) do
    ensure_table!()

    memory = %{
      id: System.unique_integer([:positive, :monotonic]),
      agent_id: agent_id,
      type: normalize_type(type),
      content: to_string(content || ""),
      metadata: metadata || %{},
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    :ets.insert(@table, {{agent_id, memory.id}, memory})
    prune_agent(agent_id)
    persist(memory)
    {:ok, memory}
  end

  def recent(agent_id, limit \\ 10) do
    ensure_table!()

    @table
    |> :ets.tab2list()
    |> Enum.filter(fn {{stored_agent_id, _id}, _memory} -> stored_agent_id == agent_id end)
    |> Enum.map(fn {_key, memory} -> memory end)
    |> Enum.sort_by(& &1.id, :desc)
    |> Enum.take(limit)
  end

  def relevant(agent_id, query, limit \\ 5) do
    ensure_table!()
    tokens = tokenize(query)

    agent_id
    |> recent(@max_per_agent)
    |> Enum.map(fn memory -> {memory_score(memory, tokens), memory} end)
    |> Enum.filter(fn {score, _memory} -> score > 0 end)
    |> Enum.sort_by(fn {score, memory} -> {score, memory.id} end, :desc)
    |> Enum.map(fn {_score, memory} -> memory end)
    |> take_or_recent(agent_id, limit)
  end

  def clear(agent_id) do
    ensure_table!()

    @table
    |> :ets.tab2list()
    |> Enum.each(fn
      {{^agent_id, id}, _memory} -> :ets.delete(@table, {agent_id, id})
      _ -> :ok
    end)

    :ok
  end

  def clear_all do
    ensure_table!()
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def handle_cast({:persist, memory}, %{path: path} = state) do
    if usable_path?(path) do
      line = Jason.encode!(memory) <> "\n"
      File.write(path, line, [:append])
    end

    {:noreply, state}
  end

  defp persist(memory) do
    if Process.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, {:persist, memory})
    end
  end

  defp prune_agent(agent_id) do
    overflow =
      agent_id
      |> recent(@max_per_agent + 25)
      |> Enum.drop(@max_per_agent)

    Enum.each(overflow, fn memory ->
      :ets.delete(@table, {agent_id, memory.id})
    end)
  end

  defp take_or_recent([], agent_id, limit), do: recent(agent_id, limit)
  defp take_or_recent(memories, _agent_id, limit), do: Enum.take(memories, limit)

  defp memory_score(memory, tokens) do
    memory_tokens =
      [memory.type, memory.content, Jason.encode!(memory.metadata || %{})]
      |> Enum.join(" ")
      |> tokenize()
      |> MapSet.new()

    overlap = Enum.count(tokens, &MapSet.member?(memory_tokens, &1))

    type_bonus =
      case memory.type do
        :reflection -> 2
        :action -> 1
        _ -> 0
      end

    overlap + type_bonus
  end

  defp tokenize(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_#]+/, " ")
    |> String.split(" ", trim: true)
    |> Enum.reject(&(String.length(&1) < 2))
  end

  defp normalize_type(type) when is_binary(type), do: String.to_atom(type)
  defp normalize_type(type) when is_atom(type), do: type
  defp normalize_type(_type), do: :note

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
