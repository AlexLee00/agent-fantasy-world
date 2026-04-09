defmodule AFW.Brain.Anthropic do
  @moduledoc "Anthropic API provider."
  @behaviour AFW.Brain.Interface

  def decide(%{prompt: prompt}) do
    api_key = Application.get_env(:afw, :anthropic_api_key, "")

    response =
      Req.post(
        "https://api.anthropic.com/v1/messages",
        headers: [
          {"x-api-key", api_key},
          {"anthropic-version", "2023-06-01"},
          {"content-type", "application/json"}
        ],
        json: %{
          model: "claude-sonnet-4-20250514",
          max_tokens: 400,
          messages: [%{role: "user", content: prompt}]
        }
      )

    with {:ok, %{status: 200, body: body}} <- response,
         [%{"text" => text} | _] <- body["content"],
         {:ok, action} <- Jason.decode(text) do
      {:ok, action}
    else
      other -> {:error, other}
    end
  end
end
