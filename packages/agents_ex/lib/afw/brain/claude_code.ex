defmodule AFW.Brain.ClaudeCode do
  @moduledoc "Claude Code CLI provider."
  @behaviour AFW.Brain.Interface

  def decide(%{prompt: prompt}) do
    cli = Application.get_env(:afw, :claude_code_path, "/opt/homebrew/bin/claude")
    model = Application.get_env(:afw, :claude_code_model, "sonnet")
    timeout_ms = Application.get_env(:afw, :claude_code_timeout_ms, 45_000)

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

    task =
      Task.async(fn ->
        System.cmd(cli, args, stderr_to_stdout: true)
      end)

    try do
      case Task.await(task, timeout_ms) do
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
    catch
      :exit, {:timeout, _} ->
        Task.shutdown(task, :brutal_kill)
        {:error, :claude_code_timeout}
    end
  end
end
