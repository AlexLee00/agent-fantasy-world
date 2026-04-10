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
    calldata = ABI.encode(selector, normalize_args(args, selector.types))
    {:ok, "0x" <> Base.encode16(calldata, case: :lower)}
  end

  def decode_call_result(function_name, result, abi_name, arity \\ 0) do
    selector = selector!(function_name, abi_name, arity)
    ABI.decode(selector, decode_hex!(result), :output)
  end

  def decode_revert("0x08c379a0" <> payload_hex) do
    payload = Base.decode16!(payload_hex, case: :mixed)

    try do
      [reason] = ABI.TypeDecoder.decode_raw(payload, [{:string}])
      reason
    rescue
      _ -> "Error(string)"
    end
  end

  def decode_revert("0x" <> <<selector::binary-size(8), _rest::binary>>) do
    "CustomError(0x#{selector})"
  end

  def decode_revert(value), do: inspect(value)

  def decode_hex!("0x" <> hex), do: Base.decode16!(hex, case: :mixed)
  def decode_hex!(hex), do: Base.decode16!(hex, case: :mixed)

  defp normalize_args(args, types) do
    Enum.zip(args, types)
    |> Enum.map(fn {arg, type} -> normalize_arg(arg, type) end)
  end

  defp normalize_arg("0x" <> hex, :address), do: String.to_integer(hex, 16)
  defp normalize_arg(arg, {:array, type}) when is_list(arg), do: Enum.map(arg, &normalize_arg(&1, type))
  defp normalize_arg(arg, {:tuple, types}) when is_list(arg), do: normalize_args(arg, types)
  defp normalize_arg(arg, {:tuple, types}) when is_tuple(arg), do: arg |> Tuple.to_list() |> normalize_args(types)
  defp normalize_arg(arg, _type), do: arg
end
