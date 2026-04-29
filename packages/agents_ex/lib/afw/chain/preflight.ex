defmodule AFW.Chain.Preflight do
  @moduledoc "Checks Base Sepolia connectivity, ABI coverage, deployed addresses, and critical roles before live runs."

  alias AFW.Chain.{ABI, Contracts, Pool, Reader, ReceiptDiagnostics}
  alias Ethereumex.HttpClient

  @chain_id 84_532

  @required_abi_checks [
    {:agent_registry, "getAgent", 1},
    {:agent_registry, "updateAgentState", 5},
    {:agent_registry, "applyCombatResult", 5},
    {:agent_registry, "ORACLE_ROLE", 0},
    {:agent_registry, "COMBAT_ROLE", 0},
    {:agent_registry, "hasRole", 2},
    {:combat_resolver, "resolveCombat", 2},
    {:monster_registry, "getMonster", 1},
    {:monster_registry, "COMBAT_ROLE", 0},
    {:monster_registry, "hasRole", 2},
    {:soul_token, "MINTER_ROLE", 0},
    {:soul_token, "BURNER_ROLE", 0},
    {:soul_token, "hasRole", 2},
    {:npc_registry, "buyFromNPC", 2},
    {:marketplace, "createOrder", 3},
    {:marketplace, "fillOrder", 1}
  ]

  @role_checks [
    %{
      contract: :monster_registry,
      role_function: "COMBAT_ROLE",
      grantee: :combat_resolver,
      label: "CombatResolver -> MonsterRegistry.COMBAT_ROLE"
    },
    %{
      contract: :soul_token,
      role_function: "MINTER_ROLE",
      grantee: :combat_resolver,
      label: "CombatResolver -> SOULToken.MINTER_ROLE"
    },
    %{
      contract: :soul_token,
      role_function: "BURNER_ROLE",
      grantee: :combat_resolver,
      label: "CombatResolver -> SOULToken.BURNER_ROLE"
    },
    %{
      contract: :agent_registry,
      role_function: "COMBAT_ROLE",
      grantee: :combat_resolver,
      label: "CombatResolver -> AgentRegistry.COMBAT_ROLE"
    },
    %{
      contract: :agent_registry,
      role_function: "ORACLE_ROLE",
      grantee: :writer,
      label: "Writer wallet -> AgentRegistry.ORACLE_ROLE"
    }
  ]

  def required_abi_checks, do: @required_abi_checks
  def role_checks, do: @role_checks

  def run do
    checks =
      []
      |> Kernel.++([rpc_check()])
      |> Kernel.++(contract_address_checks())
      |> Kernel.++(abi_checks())
      |> Kernel.++(role_grant_checks())
      |> Kernel.++(live_contract_checks())

    report = %{
      status: if(Enum.all?(checks, &(&1.status == :ok)), do: :ok, else: :failed),
      checkedAt: DateTime.utc_now(),
      checks: checks,
      failures: Enum.filter(checks, &(&1.status != :ok))
    }

    case report.status do
      :ok -> {:ok, report}
      :failed -> {:error, report}
    end
  end

  def run! do
    case run() do
      {:ok, report} -> report
      {:error, report} -> raise "AFW preflight failed: #{inspect(report.failures)}"
    end
  end

  defp rpc_check do
    case Pool.request(fn url -> HttpClient.eth_chain_id(url: url) end) do
      {:ok, chain_id_hex} ->
        chain_id = quantity_to_integer(chain_id_hex)

        if chain_id == @chain_id do
          ok(:rpc, "Base Sepolia RPC reachable", %{chainId: chain_id})
        else
          fail(:rpc, "Unexpected chain id", %{expected: @chain_id, actual: chain_id})
        end

      {:error, reason} ->
        fail(:rpc, "RPC unavailable", %{reason: inspect(reason)})
    end
  end

  defp contract_address_checks do
    contracts = Contracts.all()

    Reader.tracked_contracts()
    |> Enum.map(fn key ->
      address = Map.get(contracts, key)

      if valid_address?(address) do
        ok({:contract_address, key}, "Address configured", %{address: address})
      else
        fail({:contract_address, key}, "Missing or invalid address", %{address: inspect(address)})
      end
    end)
  end

  defp abi_checks do
    Enum.map(@required_abi_checks, fn {contract_key, function_name, arity} ->
      abi_name = abi_name(contract_key)

      try do
        ABI.selector!(function_name, abi_name, arity)
        ok({:abi, contract_key, function_name, arity}, "ABI function exists", %{})
      rescue
        error ->
          fail({:abi, contract_key, function_name, arity}, "ABI function missing", %{
            reason: Exception.message(error)
          })
      end
    end)
  end

  defp role_grant_checks do
    Enum.map(@role_checks, fn check ->
      with {:ok, role} <- read_role(check.contract, check.role_function),
           {:ok, grantee} <- grantee_address(check.grantee),
           {:ok, has_role} <- has_role(check.contract, role, grantee) do
        if has_role do
          ok({:role, check.label}, "Role granted", %{grantee: grantee})
        else
          fail({:role, check.label}, "Role missing", %{grantee: grantee})
        end
      else
        {:error, reason} ->
          fail({:role, check.label}, "Role check failed", %{reason: inspect(reason)})
      end
    end)
  end

  defp live_contract_checks do
    [agent_registry_apply_combat_result_check()]
  end

  defp agent_registry_apply_combat_result_check do
    total_agents = Reader.call_uint(:agent_registry, "totalAgents", [])

    if total_agents == 0 do
      ok(
        {:live_contract, :agent_registry, :applyCombatResult},
        "Live applyCombatResult probe skipped because no agents exist yet",
        %{}
      )
    else
      agent_id = 1
      agent = Reader.get_agent(agent_id)

      {:ok, data} =
        ABI.encode(
          "applyCombatResult",
          [
            agent_id,
            encode_stats(agent["stats"]),
            agent["experience"],
            agent["zoneId"],
            agent["statusId"]
          ],
          "AgentRegistry"
        )

      tx = %{
        "from" => Contracts.get(:combat_resolver),
        "to" => Contracts.get(:agent_registry),
        "data" => data
      }

      case Pool.request(fn url -> HttpClient.eth_call(tx, "latest", url: url) end) do
        {:ok, _} ->
          ok(
            {:live_contract, :agent_registry, :applyCombatResult},
            "AgentRegistry.applyCombatResult is reachable from CombatResolver",
            %{agentId: agent_id}
          )

        {:error, reason} ->
          decoded = ReceiptDiagnostics.extract_revert_reason(reason) || inspect(reason)

          fail(
            {:live_contract, :agent_registry, :applyCombatResult},
            "AgentRegistry.applyCombatResult live probe failed",
            %{agentId: agent_id, reason: decoded}
          )
      end
    end
  rescue
    error ->
      fail(
        {:live_contract, :agent_registry, :applyCombatResult},
        "AgentRegistry.applyCombatResult live probe failed",
        %{reason: Exception.message(error)}
      )
  end

  defp read_role(contract, role_function) do
    case role_constant(role_function) do
      nil ->
        case Reader.call_contract(contract, role_function, []) do
          [role] -> {:ok, role}
          role -> {:ok, role}
        end

      role ->
        {:ok, role}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp has_role(contract, role, grantee) do
    {:ok, Reader.call_bool(contract, "hasRole", [role, grantee])}
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp grantee_address(:writer), do: {:ok, Reader.account_address()}

  defp grantee_address(contract_key) when is_atom(contract_key) do
    case Contracts.get(contract_key) do
      nil -> {:error, {:missing_contract, contract_key}}
      address -> {:ok, address}
    end
  end

  defp role_constant("COMBAT_ROLE"), do: ExKeccak.hash_256("COMBAT_ROLE")
  defp role_constant("ORACLE_ROLE"), do: ExKeccak.hash_256("ORACLE_ROLE")
  defp role_constant("MINTER_ROLE"), do: ExKeccak.hash_256("MINTER_ROLE")
  defp role_constant("BURNER_ROLE"), do: ExKeccak.hash_256("BURNER_ROLE")
  defp role_constant(_role_function), do: nil

  defp encode_stats(stats) do
    [
      stats["hp"],
      stats["maxHp"],
      stats["mp"],
      stats["maxMp"],
      stats["attack"],
      stats["defense"],
      stats["speed"]
    ]
  end

  defp ok(name, message, details),
    do: %{name: label(name), status: :ok, message: message, details: details}

  defp fail(name, message, details),
    do: %{name: label(name), status: :failed, message: message, details: details}

  defp label(name) when is_tuple(name) do
    name
    |> Tuple.to_list()
    |> Enum.map_join(".", &label/1)
  end

  defp label(name) when is_atom(name), do: Atom.to_string(name)
  defp label(name), do: to_string(name)

  defp valid_address?("0x" <> rest),
    do: byte_size(rest) == 40 and Regex.match?(~r/\A[0-9a-fA-F]+\z/, rest)

  defp valid_address?(_), do: false

  defp quantity_to_integer("0x"), do: 0
  defp quantity_to_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp quantity_to_integer(value) when is_integer(value), do: value

  defp abi_name(contract_key) do
    contract_key
    |> Atom.to_string()
    |> Macro.camelize()
  end
end
