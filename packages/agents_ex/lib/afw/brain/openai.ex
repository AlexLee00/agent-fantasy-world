defmodule AFW.Brain.OpenAI do
  @moduledoc "OpenAI API provider."
  @behaviour AFW.Brain.Interface

  def decide(%{prompt: prompt}) do
    api_key = Application.get_env(:afw, :openai_api_key, "")

    response =
      Req.post(
        "https://api.openai.com/v1/chat/completions",
        headers: [
          {"authorization", "Bearer " <> api_key},
          {"content-type", "application/json"}
        ],
        json: %{
          model: "gpt-4o-mini",
          messages: [%{role: "user", content: prompt}],
          response_format: %{type: "json_object"}
        }
      )

    with {:ok, %{status: 200, body: body}} <- response,
         [%{"message" => %{"content" => content}} | _] <- body["choices"],
         {:ok, action} <- Jason.decode(content) do
      {:ok, action}
    else
      other -> {:error, other}
    end
  end
end
