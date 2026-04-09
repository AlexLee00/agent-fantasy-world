defmodule AFW.Chain.ABI do
  @moduledoc "Loads ABI JSON files and provides simple selector helpers."

  @abi_path Path.expand("../../../priv/abi", __DIR__)

  def load!(name) do
    path = Path.join(@abi_path, "#{name}.json")

    path
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("abi")
  end

  def encode(function_name, args \\ [], abi_name) do
    abi = load!(abi_name)

    signature =
      abi
      |> Enum.find(fn entry ->
        entry["type"] == "function" and entry["name"] == function_name and
          length(entry["inputs"] || []) == length(args)
      end)

    {:ok, %{signature: signature, args: args}}
  end

  def decode_call_result(_function_name, result, _abi_name), do: result
end
