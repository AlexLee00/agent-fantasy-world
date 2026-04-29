defmodule AFW.Chain.PreflightTest do
  use ExUnit.Case, async: true

  alias AFW.Chain.{Client, Preflight}

  test "required ABI checks resolve against bundled artifacts" do
    for {contract_key, function_name, arity} <- Preflight.required_abi_checks() do
      abi_name = contract_key |> Atom.to_string() |> Macro.camelize()
      selector = AFW.Chain.ABI.selector!(function_name, abi_name, arity)
      assert selector.type == :function
    end
  end

  test "role checks describe Phase 0 critical permissions" do
    labels = Enum.map(Preflight.role_checks(), & &1.label)

    assert "CombatResolver -> MonsterRegistry.COMBAT_ROLE" in labels
    assert "CombatResolver -> SOULToken.MINTER_ROLE" in labels
    assert "CombatResolver -> SOULToken.BURNER_ROLE" in labels
    assert "CombatResolver -> AgentRegistry.COMBAT_ROLE" in labels
    assert "Writer wallet -> AgentRegistry.ORACLE_ROLE" in labels
  end

  test "tracked contracts still cover the Phase 0 on-chain surface" do
    assert length(Client.tracked_contracts()) == 15
    assert :combat_resolver in Client.tracked_contracts()
    assert :monster_registry in Client.tracked_contracts()
    assert :marketplace in Client.tracked_contracts()
  end
end
