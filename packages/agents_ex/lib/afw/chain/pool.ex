defmodule AFW.Chain.Pool do
  @moduledoc "Small RPC endpoint helper with round-robin ordering and fallback retries."

  @table :afw_rpc_pool

  def rpc_urls do
    Application.get_env(:afw, :rpc_urls, [])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def request(fun) when is_function(fun, 1) do
    rpc_urls()
    |> prioritize()
    |> do_request(fun)
  end

  defp do_request([], _fun), do: {:error, :no_rpc_available}

  defp do_request([url | rest], fun) do
    started = System.monotonic_time(:millisecond)

    case fun.(url) do
      {:ok, _} = ok ->
        record(url, System.monotonic_time(:millisecond) - started)
        ok

      {:error, _reason} = error ->
        record(url, 60_000)
        case rest do
          [] -> error
          _ -> do_request(rest, fun)
        end
    end
  end

  defp prioritize([]), do: []

  defp prioritize(urls) do
    ensure_table!()

    urls
    |> Enum.map(fn url ->
      latency =
        case :ets.lookup(@table, url) do
          [{^url, latency_ms, _}] -> latency_ms
          _ -> 10_000
        end

      {url, latency}
    end)
    |> Enum.sort_by(fn {_url, latency} -> latency end)
    |> Enum.map(&elem(&1, 0))
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])

      _ ->
        @table
    end
  end

  defp record(url, latency_ms) do
    ensure_table!()
    :ets.insert(@table, {url, latency_ms, System.monotonic_time(:millisecond)})
  end
end
