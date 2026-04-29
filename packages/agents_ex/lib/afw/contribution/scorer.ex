defmodule AFW.Contribution.Scorer do
  @moduledoc "Computes epoch contribution scores."

  def score(%{github: github, on_chain: on_chain}) do
    %{
      developers: developer_scores(github),
      nodes: node_scores(on_chain[:nodes] || []),
      creators: creator_scores(on_chain[:creators] || [])
    }
  end

  def developer_scores(github) do
    [
      %{
        address: "github:repo",
        score:
          (github[:prs_merged] || 0) * 100 + (github[:issues_closed] || 0) * 50 +
            (github[:commits] || 0) * 10
      }
    ]
  end

  def node_scores(nodes) do
    Enum.map(nodes, fn node ->
      %{
        address: node.address,
        score: node.inference_count * 0.6 + node.uptime_pct * 0.3 + node.quality * 0.1
      }
    end)
  end

  def creator_scores(creators) do
    Enum.map(creators, fn creator ->
      %{address: creator.address, score: creator.content_uses * 20}
    end)
  end
end
