defmodule AFW.Contribution.GitHub do
  @moduledoc "GitHub API helpers for the Contribution Agent."

  def fetch_metrics do
    repo = Application.get_env(:afw, :github_repo, "AlexLee00/agent-fantasy-world")
    token = Application.get_env(:afw, :github_token, "")
    headers = if token == "", do: [], else: [{"authorization", "Bearer " <> token}]

    %{
      commits: fetch_count("https://api.github.com/repos/#{repo}/commits", headers),
      prs_merged: fetch_count("https://api.github.com/repos/#{repo}/pulls?state=closed", headers, &merged_prs/1),
      issues_closed: fetch_count("https://api.github.com/repos/#{repo}/issues?state=closed", headers, &closed_issues/1)
    }
  end

  defp fetch_count(url, headers, reducer \\ &length/1) do
    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: body}} when is_list(body) -> reducer.(body)
      _ -> 0
    end
  end

  defp merged_prs(prs), do: Enum.count(prs, &(&1["merged_at"] != nil))
  defp closed_issues(issues), do: Enum.count(issues, &(Map.get(&1, "pull_request") == nil))
end
