defmodule AFW.Contribution.RecipientMapTest do
  use ExUnit.Case, async: false

  alias AFW.Contribution.{RecipientMap, Scorer}

  setup do
    previous_map = Application.get_env(:afw, :contribution_recipient_map, %{})
    previous_address = Application.get_env(:afw, :contribution_developer_reward_address, "")

    on_exit(fn ->
      Application.put_env(:afw, :contribution_recipient_map, previous_map)
      Application.put_env(:afw, :contribution_developer_reward_address, previous_address)
    end)

    :ok
  end

  test "resolves configured contribution identity to an EVM address" do
    Application.put_env(:afw, :contribution_recipient_map, %{
      "github:repo" => "0x4444444444444444444444444444444444444444"
    })

    assert RecipientMap.resolve("github:repo") == "0x4444444444444444444444444444444444444444"
  end

  test "developer score prefers recipient map over fallback address" do
    Application.put_env(:afw, :contribution_recipient_map, %{
      "github:repo" => "0x5555555555555555555555555555555555555555"
    })

    Application.put_env(
      :afw,
      :contribution_developer_reward_address,
      "0x3333333333333333333333333333333333333333"
    )

    assert [%{address: "0x5555555555555555555555555555555555555555"}] =
             Scorer.developer_scores(%{prs_merged: 1, issues_closed: 0, commits: 0})
  end
end
