defmodule AFW.Contribution.RecipientMap do
  @moduledoc "Resolves contribution identities to EVM payout addresses."

  def resolve(identity) when is_binary(identity) do
    configured_map()
    |> Map.get(identity)
    |> normalize_address()
  end

  def resolve(_identity), do: nil

  def valid_evm_address?(value) when is_binary(value), do: value =~ ~r/^0x[0-9a-fA-F]{40}$/
  def valid_evm_address?(_value), do: false

  def configured_map do
    Application.get_env(:afw, :contribution_recipient_map, %{})
    |> normalize_map()
  end

  defp normalize_map(value) when is_map(value) do
    Map.new(value, fn {identity, address} -> {to_string(identity), address} end)
  end

  defp normalize_map(_value), do: %{}

  defp normalize_address(address) when is_binary(address) do
    if valid_evm_address?(address), do: address, else: nil
  end

  defp normalize_address(_address), do: nil
end
