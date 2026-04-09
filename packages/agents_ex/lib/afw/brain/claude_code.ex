defmodule AFW.Brain.ClaudeCode do
  @moduledoc "Claude Code CLI provider."
  @behaviour AFW.Brain.Interface

  def decide(%{prompt: prompt}) do
    cli = Application.get_env(:afw, :claude_code_path, "/opt/homebrew/bin/claude")
    model = Application.get_env(:afw, :claude_code_model, "sonnet")

    args = [
      "-p",
      "--output-format",
      "json",
      "--model",
      model,
      "--max-turns",
      "1",
      "--tools",
      "",
      "--permission-mode",
      "default",
      "--no-session-persistence",
      prompt
    ]

    case System.cmd(cli, args, stderr_to_stdout: true) do
      {output, 0} ->
        with {:ok, payload} <- Jason.decode(output),
             result when is_binary(result) <- Map.get(payload, "result"),
             {:ok, action} <- Jason.decode(result) do
          {:ok, action}
        else
          _ -> {:error, :invalid_claude_payload}
        end

      {output, code} ->
        {:error, {:claude_code_failed, code, output}}
    end
  end
end
