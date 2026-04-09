defmodule AFW.Contribution.OnChain do
  @moduledoc "On-chain contribution metrics from AFW contracts."

  alias AFW.Chain.Client

  def fetch_metrics do
    %{
      nodes: Client.get_node_stats(),
      creators: Client.get_creator_stats()
    }
  end
end
