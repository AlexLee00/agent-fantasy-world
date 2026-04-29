defmodule AFW.Chain.ReceiptDiagnosticsTest do
  use ExUnit.Case, async: true

  alias AFW.Chain.{ABI, ReceiptDiagnostics}

  test "decodes Error(string) revert payloads" do
    reason = "CombatResolver: monster dead"
    assert ABI.decode_revert(error_string_payload(reason)) == reason

    assert ReceiptDiagnostics.extract_revert_reason(%{"data" => error_string_payload(reason)}) ==
             reason
  end

  test "maps known custom error selectors to names" do
    reason = ABI.decode_revert("0xe2517d3f" <> String.duplicate("0", 128))
    assert reason == "CustomError(AccessControlUnauthorizedAccount(address,bytes32))"
  end

  test "keeps unknown custom error selectors visible" do
    assert ABI.decode_revert("0xdeadbeef" <> String.duplicate("0", 64)) ==
             "CustomError(0xdeadbeef)"
  end

  test "diagnoses block-specific eth_call reverts through injectable call function" do
    call_fun = fn tx, block ->
      assert tx["to"] == "0xabc"
      assert block == "0x123"
      {:error, %{"data" => error_string_payload("OrderNotActive")}}
    end

    assert {:error, {:revert, "OrderNotActive"}} =
             ReceiptDiagnostics.diagnose_at_block(%{"to" => "0xabc"}, "0x123", call_fun)
  end

  defp error_string_payload(reason) do
    bytes = reason
    length = byte_size(bytes)
    padded_bytes = pad_right(bytes)

    "0x08c379a0" <>
      pad_left(Integer.to_string(32, 16)) <>
      pad_left(Integer.to_string(length, 16)) <>
      Base.encode16(padded_bytes, case: :lower)
  end

  defp pad_left(hex), do: String.pad_leading(hex, 64, "0")

  defp pad_right(bytes) do
    padding = rem(32 - rem(byte_size(bytes), 32), 32)
    bytes <> :binary.copy(<<0>>, padding)
  end
end
