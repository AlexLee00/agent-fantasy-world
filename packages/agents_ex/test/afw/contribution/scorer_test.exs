defmodule AFW.Contribution.ScorerTest do
  use ExUnit.Case, async: true

  test "computes node, developer, and creator scores" do
    result =
      AFW.Contribution.Scorer.score(%{
        github: %{prs_merged: 2, issues_closed: 3, commits: 5},
        on_chain: %{
          nodes: [%{address: "0x1", inference_count: 100, uptime_pct: 90, quality: 80}],
          creators: [%{address: "0x2", content_uses: 7}]
        }
      })

    assert [%{score: dev_score}] = result.developers
    assert dev_score == 2 * 100 + 3 * 50 + 5 * 10

    assert [%{score: node_score}] = result.nodes
    assert Float.round(node_score, 1) == 95.0

    assert [%{score: creator_score}] = result.creators
    assert creator_score == 140
  end

  test "excludes inactive or verification-failed nodes from reward scores" do
    assert [
             %{
               address: "0x1111111111111111111111111111111111111111",
               score: _
             }
           ] =
             AFW.Contribution.Scorer.node_scores([
               %{
                 active: true,
                 reward_eligible: true,
                 address: "0x1111111111111111111111111111111111111111",
                 inference_count: 10,
                 uptime_pct: 100,
                 quality: 100
               },
               %{
                 active: true,
                 reward_eligible: false,
                 address: "0x2222222222222222222222222222222222222222",
                 inference_count: 100,
                 uptime_pct: 100,
                 quality: 100
               },
               %{
                 active: false,
                 reward_eligible: true,
                 address: "0x3333333333333333333333333333333333333333",
                 inference_count: 100,
                 uptime_pct: 100,
                 quality: 100
               }
             ])
  end
end
