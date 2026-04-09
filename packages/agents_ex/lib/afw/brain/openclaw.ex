defmodule AFW.Brain.OpenClaw do
  @moduledoc "Tier 3 OpenClaw provider."
  @behaviour AFW.Brain.Interface

  def decide(%{prompt: prompt}) do
    host = Application.get_env(:afw, :openclaw_host, "http://localhost:18789")

    with {:ok, %{status: 200, body: body}} <-
           Req.post(
             host <> "/v1/decide",
             json: %{prompt: prompt},
             receive_timeout: 10_000
           ),
         action when is_map(action) <- body["action"] || body do
      {:ok, action}
    else
      other -> {:error, other}
    end
  end
end
