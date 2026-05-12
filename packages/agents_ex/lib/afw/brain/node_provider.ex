defmodule AFW.Brain.NodeProvider do
  @moduledoc "Tier 4 node-backed brain provider."
  @behaviour AFW.Brain.Interface

  alias AFW.Chain.Client

  def decide(%{prompt: prompt}) do
    case Client.get_node_stats() do
      [%{endpoint: endpoint} | _] when is_binary(endpoint) and endpoint != "" ->
        with {:ok, %{status: 200, body: body}} <-
               Req.post(endpoint, json: %{prompt: prompt}, receive_timeout: 10_000),
             decoded <- decode_body(body),
             action when is_map(action) <- decoded["action"] || decoded do
          {:ok, action}
        else
          other -> {:error, other}
        end

      _ ->
        {:error, :no_available_node}
    end
  end

  defp decode_body(body) when is_map(body), do: body

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{}
    end
  end

  defp decode_body(_body), do: %{}
end
