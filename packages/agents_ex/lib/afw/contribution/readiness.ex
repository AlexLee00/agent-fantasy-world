defmodule AFW.Contribution.Readiness do
  @moduledoc "Production readiness checks for Phase 2 contribution rewards."

  alias AFW.Chain.Client
  alias AFW.Contribution.RecipientMap
  alias AFW.Tier4.EndpointVerifier

  @distribution_keys [
    :afw_distributor,
    :node_reward_pool,
    :bounty_pool,
    :ecosystem_treasury,
    :team_vesting_wallet,
    :advisor_vesting_wallet
  ]

  def check(opts \\ []) do
    account_address = Keyword.get_lazy(opts, :account_address, &Client.account_address/0)
    contracts = Keyword.get(opts, :contracts, Application.get_env(:afw, :contracts, %{}))
    nodes = Keyword.get_lazy(opts, :nodes, &Client.get_node_stats/0)
    recipient_map = Keyword.get(opts, :recipient_map, RecipientMap.configured_map())
    verify_endpoints = Keyword.get(opts, :verify_endpoints, false)
    endpoint_verifier = Keyword.get(opts, :endpoint_verifier, &EndpointVerifier.verify/1)

    checks = [
      distribution_contracts_check(contracts),
      payout_mapping_check(recipient_map),
      payout_owner_check(recipient_map, account_address),
      tier4_node_check(nodes),
      tier4_endpoint_check(nodes, verify_endpoints, endpoint_verifier)
    ]

    %{
      status: if(Enum.all?(checks, &(&1.status == :pass)), do: :passed, else: :blocked),
      checkedAt: DateTime.utc_now(),
      checks: checks
    }
  end

  def external_endpoint?(endpoint) when is_binary(endpoint) do
    EndpointVerifier.external_endpoint?(endpoint)
  end

  def external_endpoint?(_endpoint), do: false

  defp distribution_contracts_check(contracts) do
    missing =
      @distribution_keys
      |> Enum.reject(fn key -> valid_address?(Map.get(contracts, key)) end)

    %{
      id: "distribution_contracts",
      status: if(missing == [], do: :pass, else: :fail),
      detail:
        if(missing == [],
          do: "All distribution contracts are configured.",
          else: "Missing or invalid contracts: #{Enum.join(missing, ", ")}"
        )
    }
  end

  defp payout_mapping_check(recipient_map) do
    invalid =
      recipient_map
      |> Enum.reject(fn {_identity, address} -> valid_address?(address) end)

    cond do
      map_size(recipient_map) == 0 ->
        %{
          id: "contributor_payout_mapping",
          status: :fail,
          detail: "No contributor payout mapping configured."
        }

      invalid != [] ->
        %{
          id: "contributor_payout_mapping",
          status: :fail,
          detail:
            "Invalid payout addresses for: #{invalid |> Enum.map(fn {id, _} -> id end) |> Enum.join(", ")}"
        }

      true ->
        %{
          id: "contributor_payout_mapping",
          status: :pass,
          detail: "#{map_size(recipient_map)} contributor payout mapping(s) configured."
        }
    end
  end

  defp payout_owner_check(recipient_map, account_address) do
    deployer_recipients =
      recipient_map
      |> Enum.filter(fn {_identity, address} -> same_address?(address, account_address) end)
      |> Enum.map(fn {identity, _address} -> identity end)

    %{
      id: "production_payout_ownership",
      status: if(deployer_recipients == [], do: :pass, else: :fail),
      detail:
        if(deployer_recipients == [],
          do: "No payout mapping points at the executor wallet.",
          else: "Mappings still point at executor wallet: #{Enum.join(deployer_recipients, ", ")}"
        )
    }
  end

  defp tier4_node_check(nodes) do
    active = Enum.filter(nodes, &Map.get(&1, :active, true))

    %{
      id: "tier4_node_registered",
      status: if(active == [], do: :fail, else: :pass),
      detail:
        if(active == [],
          do: "No active Tier 4 node is registered.",
          else: "#{length(active)} active Tier 4 node(s) registered."
        )
    }
  end

  defp tier4_endpoint_check(nodes, verify_endpoints, endpoint_verifier) do
    endpoints =
      nodes
      |> Enum.filter(&Map.get(&1, :active, true))
      |> Enum.map(&Map.get(&1, :endpoint))
      |> Enum.filter(&is_binary/1)

    external = Enum.filter(endpoints, &external_endpoint?/1)

    cond do
      external == [] ->
        %{
          id: "tier4_external_endpoint",
          status: :fail,
          detail: "No externally reachable Tier 4 endpoint found."
        }

      verify_endpoints ->
        verified =
          Enum.flat_map(external, fn endpoint ->
            case endpoint_verifier.(endpoint) do
              {:ok, result} -> [{:ok, result}]
              {:error, reason} -> [{:error, reason}]
            end
          end)

        passed = Enum.filter(verified, &match?({:ok, _}, &1))

        %{
          id: "tier4_external_endpoint",
          status: if(passed == [], do: :fail, else: :pass),
          detail: endpoint_verification_detail(verified)
        }

      true ->
        %{
          id: "tier4_external_endpoint",
          status: :pass,
          detail: "External Tier 4 endpoint(s): #{Enum.join(external, ", ")}"
        }
    end
  end

  defp endpoint_verification_detail(verified) do
    verified
    |> Enum.map(fn
      {:ok, %{endpoint: endpoint}} -> "verified #{endpoint}"
      {:error, %{endpoint: endpoint, reason: reason}} -> "failed #{endpoint}: #{inspect(reason)}"
      {:error, reason} -> "failed: #{inspect(reason)}"
    end)
    |> Enum.join("; ")
  end

  defp valid_address?(address), do: RecipientMap.valid_evm_address?(address)

  defp same_address?(left, right) when is_binary(left) and is_binary(right) do
    String.downcase(left) == String.downcase(right)
  end

  defp same_address?(_left, _right), do: false
end
