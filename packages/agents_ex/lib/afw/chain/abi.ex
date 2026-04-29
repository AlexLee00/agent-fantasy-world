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
    decode_error_string(payload)
  end

  def decode_revert("0x" <> <<selector::binary-size(8), _rest::binary>>) do
    case custom_error_signature(selector) do
      nil -> "CustomError(0x#{selector})"
      signature -> "CustomError(#{signature})"
    end
  end

  def decode_revert(value), do: inspect(value)

  def decode_hex!("0x" <> hex), do: Base.decode16!(hex, case: :mixed)
  def decode_hex!(hex), do: Base.decode16!(hex, case: :mixed)

  def custom_error_signature(selector_hex) when is_binary(selector_hex) do
    selector = String.downcase(String.replace_prefix(selector_hex, "0x", ""))

    custom_error_signatures()
    |> Map.get(selector)
  end

  defp normalize_args(args, types) do
    Enum.zip(args, types)
    |> Enum.map(fn {arg, type} -> normalize_arg(arg, type) end)
  end

  defp normalize_arg("0x" <> hex, :address), do: String.to_integer(hex, 16)

  defp normalize_arg(arg, {:array, type}) when is_list(arg),
    do: Enum.map(arg, &normalize_arg(&1, type))

  defp normalize_arg(arg, {:tuple, types}) when is_list(arg), do: normalize_args(arg, types)

  defp normalize_arg(arg, {:tuple, types}) when is_tuple(arg),
    do: arg |> Tuple.to_list() |> normalize_args(types)

  defp normalize_arg(arg, _type), do: arg

  defp decode_error_string(<<offset::unsigned-size(256), rest::binary>>) do
    start = max(offset - 32, 0)

    with <<_skip::binary-size(start), length::unsigned-size(256), data::binary>> <- rest,
         <<reason::binary-size(length), _padding::binary>> <- data do
      reason
    else
      _ -> "Error(string)"
    end
  rescue
    _ -> "Error(string)"
  end

  defp decode_error_string(_payload), do: "Error(string)"

  defp custom_error_signatures do
    :persistent_term.get({__MODULE__, :custom_error_signatures}, nil)
    |> case do
      nil ->
        signatures =
          @abi_path
          |> Path.join("*.json")
          |> Path.wildcard()
          |> Enum.flat_map(&error_signatures_from_file/1)
          |> Map.new()

        :persistent_term.put({__MODULE__, :custom_error_signatures}, signatures)
        signatures

      signatures ->
        signatures
    end
  end

  defp error_signatures_from_file(path) do
    path
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("abi")
    |> Enum.filter(&(&1["type"] == "error"))
    |> Enum.map(fn entry ->
      signature =
        "#{entry["name"]}(#{entry |> Map.get("inputs", []) |> Enum.map_join(",", & &1["type"])})"

      selector =
        entry["name"]
        |> error_selector(entry["inputs"] || [])
        |> Base.encode16(case: :lower)

      {selector, signature}
    end)
  rescue
    _ -> []
  end

  defp error_selector(name, inputs) do
    canonical = "#{name}(#{Enum.map_join(inputs, ",", & &1["type"])})"
    ExKeccak.hash_256(canonical) |> binary_part(0, 4)
  end
end
