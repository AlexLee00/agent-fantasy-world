defmodule AFW.Memory.SQLite do
  @moduledoc """
  Small SQLite adapter for durable memory without adding a new Elixir DB stack.

  It uses the local `sqlite3` executable. If the executable is unavailable, the
  caller can continue with ETS-only memory.
  """

  require Logger

  @schema """
  CREATE TABLE IF NOT EXISTS memories (
    agent_id INTEGER NOT NULL,
    id INTEGER NOT NULL,
    type TEXT NOT NULL,
    content TEXT NOT NULL,
    metadata_json TEXT NOT NULL,
    embedding_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (agent_id, id)
  );
  CREATE INDEX IF NOT EXISTS memories_agent_created_idx
    ON memories(agent_id, created_at DESC);
  """

  def available?, do: not is_nil(System.find_executable("sqlite3"))

  def init(nil), do: :disabled
  def init(""), do: :disabled

  def init(path) do
    if available?() do
      File.mkdir_p!(Path.dirname(path))
      run(path, @schema)
      :ok
    else
      Logger.warning("[memory] sqlite3 executable not found; durable memory disabled")
      :disabled
    end
  end

  def insert(path, memory) when is_binary(path) do
    sql = """
    INSERT OR REPLACE INTO memories
      (agent_id, id, type, content, metadata_json, embedding_json, created_at)
    VALUES
      (#{memory.agent_id}, #{memory.id}, #{sql_quote(to_string(memory.type))},
       #{sql_quote(memory.content)}, #{sql_quote(Jason.encode!(memory.metadata || %{}))},
       #{sql_quote(Jason.encode!(memory.embedding || []))}, #{sql_quote(memory.created_at)});
    """

    run(path, sql)
  end

  def insert(_path, _memory), do: :disabled

  def load_recent(path, limit \\ 1_000)

  def load_recent(path, limit) when is_binary(path) do
    if available?() and File.exists?(path) do
      sql = """
      SELECT agent_id, id, type, content, metadata_json, embedding_json, created_at
      FROM memories
      ORDER BY id DESC
      LIMIT #{limit};
      """

      case run(path, sql, json: true) do
        {:ok, ""} ->
          []

        {:ok, output} ->
          output
          |> Jason.decode!()
          |> Enum.map(&decode_row/1)

        _ ->
          []
      end
    else
      []
    end
  end

  def load_recent(_path, _limit), do: []

  def clear_all(path) when is_binary(path) do
    if available?() and File.exists?(path), do: run(path, "DELETE FROM memories;")
    :ok
  end

  def clear_all(_path), do: :ok

  defp decode_row(row) do
    %{
      agent_id: row["agent_id"],
      id: row["id"],
      type: String.to_atom(row["type"]),
      content: row["content"],
      metadata: Jason.decode!(row["metadata_json"]),
      embedding: Jason.decode!(row["embedding_json"]),
      created_at: row["created_at"]
    }
  end

  defp run(path, sql, opts \\ []) do
    args =
      if Keyword.get(opts, :json, false) do
        ["-json", path, sql]
      else
        [path, sql]
      end

    case System.cmd("sqlite3", args, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {output, code} ->
        Logger.warning("[memory] sqlite failed code=#{code}: #{String.trim(output)}")
        {:error, output}
    end
  end

  defp sql_quote(value) do
    "'#{String.replace(to_string(value), "'", "''")}'"
  end
end
