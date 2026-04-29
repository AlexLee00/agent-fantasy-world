defmodule AFW.Chain.Cache do
  @moduledoc "Small ETS TTL cache for repeated chain reads."
  use GenServer

  @table :afw_chain_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    ensure_table!()
    {:ok, state}
  end

  def get_or_fetch(key, ttl_ms, fetch_fn) when is_function(fetch_fn, 0) do
    ensure_table!()

    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] when expires_at > now ->
        value

      _ ->
        value = fetch_fn.()
        :ets.insert(@table, {key, value, now + ttl_ms})
        value
    end
  end

  def invalidate(key) do
    ensure_table!()
    :ets.delete(@table, key)
    :ok
  end

  def invalidate_prefix(prefix) do
    ensure_table!()

    @table
    |> :ets.tab2list()
    |> Enum.each(fn
      {key, _, _} when is_tuple(key) and tuple_size(key) > 0 and elem(key, 0) == prefix ->
        :ets.delete(@table, key)

      _ ->
        :ok
    end)

    :ok
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
end
