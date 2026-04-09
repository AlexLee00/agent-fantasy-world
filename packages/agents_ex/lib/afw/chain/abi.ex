defmodule AFW.Chain.ABI do
  @moduledoc "Loads ABI JSON files and provides calldata encode/decode helpers."

  @abi_path Path.expand("../../../priv/abi", __DIR__)

  def load!(name) do
    path = Path.join(@abi_path, "#{name}.json")

    path
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("abi")
  end

  def selectors!(abi_name) do
    abi_name
    |> load!()
    |> ABI.parse_specification(include_events?: true)
  end

  def selector!(function_name, abi_name, arity \\ nil) do
    selectors!(abi_name)
    |> Enum.find(fn selector ->
      selector.type == :function and selector.function == function_name and
        (is_nil(arity) or length(selector.types) == arity)
    end)
    |> case do
      nil ->
        raise ArgumentError, "Function #{function_name}/#{arity || "*"} not found in #{abi_name}"

      selector ->
        selector
    end
  end

  def encode(function_name, args \\ [], abi_name) do
    selector = selector!(function_name, abi_name, length(args))
    calldata = ABI.encode(selector, args)
    {:ok, "0x" <> Base.encode16(calldata, case: :lower)}
  end

  def decode_call_result(function_name, result, abi_name, arity \\ 0) do
    selector = selector!(function_name, abi_name, arity)
    ABI.decode(selector, decode_hex!(result), :output)
  end

  def decode_hex!("0x" <> hex), do: Base.decode16!(hex, case: :mixed)
  def decode_hex!(hex), do: Base.decode16!(hex, case: :mixed)
end
