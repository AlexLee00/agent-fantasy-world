defmodule AFW.Chain.ReceiptDiagnostics do
  @moduledoc "Diagnoses reverted write transactions using receipt-block eth_call replay."
  require Logger

  alias AFW.Chain.{ABI, Pool}
  alias Ethereumex.HttpClient

  @basescan_tx_base "https://sepolia.basescan.org/tx/"

  def basescan_tx_url(tx_hash), do: @basescan_tx_base <> tx_hash

  def diagnose_at_block(tx, block_tag, call_fun \\ &eth_call/2) do
    case call_fun.(tx, block_tag) do
      {:ok, _result} ->
        {:ok, :no_revert_data}

      {:error, reason} ->
        case extract_revert_reason(reason) do
          nil -> {:error, :call_failed}
          revert_reason -> {:error, {:revert, revert_reason}}
        end
    end
  end

  def extract_revert_reason(%{"error" => nested}), do: extract_revert_reason(nested)
  def extract_revert_reason(%{error: nested}), do: extract_revert_reason(nested)

  def extract_revert_reason(%{"data" => data, "message" => message}) when is_binary(data) do
    data
    |> decode_revert_data()
    |> fallback_reason(message)
  end

  def extract_revert_reason(%{data: data, message: message}) when is_binary(data) do
    data
    |> decode_revert_data()
    |> fallback_reason(message)
  end

  def extract_revert_reason(%{"data" => data}) when is_binary(data), do: decode_revert_data(data)
  def extract_revert_reason(%{data: data}) when is_binary(data), do: decode_revert_data(data)

  def extract_revert_reason(%{"message" => message}) when is_binary(message),
    do: normalize_message(message)

  def extract_revert_reason(%{message: message}) when is_binary(message),
    do: normalize_message(message)

  def extract_revert_reason(message) when is_binary(message), do: normalize_message(message)

  def extract_revert_reason(reason) do
    reason
    |> inspect()
    |> normalize_message()
  end

  def log_reverted_receipt(details) when is_map(details) do
    tx_hash = Map.fetch!(details, :tx_hash)
    contract = Map.fetch!(details, :contract)
    function = Map.fetch!(details, :function)
    gas = Map.get(details, :gas)
    nonce = Map.get(details, :nonce)
    block_number = Map.get(details, :block_number, "unknown")
    reason = Map.get(details, :reason, "undetermined")

    Logger.error(
      "[writer] reverted tx contract=#{contract} function=#{function} hash=#{tx_hash} block=#{block_number} gas=#{gas} nonce=#{nonce} reason=#{reason} basescan=#{basescan_tx_url(tx_hash)}"
    )

    details
  end

  defp eth_call(tx, block_tag) do
    Pool.request(fn url -> HttpClient.eth_call(tx, block_tag, url: url) end)
  end

  defp decode_revert_data("0x"), do: nil

  defp decode_revert_data("0x" <> hex) when byte_size(hex) >= 8,
    do: ABI.decode_revert("0x" <> hex)

  defp decode_revert_data(data) when is_binary(data), do: normalize_message(data)

  defp fallback_reason(nil, message), do: normalize_message(message)
  defp fallback_reason(reason, _message), do: reason

  defp normalize_message(nil), do: nil

  defp normalize_message(message) when is_binary(message) do
    cond do
      message == "" ->
        nil

      String.contains?(message, "execution reverted:") ->
        message
        |> String.split("execution reverted:")
        |> List.last()
        |> String.trim()

      String.contains?(message, "CombatResolver: monster dead") ->
        "CombatResolver: monster dead"

      String.contains?(message, "AgentRegistry: agent not found") ->
        "AgentRegistry: agent not found"

      String.contains?(message, "AgentRegistry: status not found") ->
        "AgentRegistry: status not found"

      String.contains?(message, "MonsterRegistry: already dead") ->
        "MonsterRegistry: already dead"

      String.contains?(message, "MonsterRegistry: monster dead") ->
        "MonsterRegistry: monster dead"

      String.contains?(message, "AgentNotAlive") ->
        "AgentNotAlive"

      String.contains?(message, "MonsterNotAlive") ->
        "MonsterNotAlive"

      String.contains?(message, "InsufficientBalance") ->
        "InsufficientBalance"

      String.contains?(message, "InsufficientSOUL") ->
        "InsufficientSOUL"

      String.contains?(message, "OrderNotActive") ->
        "OrderNotActive"

      String.contains?(message, "InsufficientItemBalance") ->
        "InsufficientItemBalance"

      String.contains?(message, "ZeroAmount") ->
        "ZeroAmount"

      String.contains?(message, "ItemNotAvailable") ->
        "ItemNotAvailable"

      String.contains?(message, "Unauthorized") ->
        "Unauthorized"

      String.contains?(message, "revert") ->
        message

      true ->
        nil
    end
  end
end
