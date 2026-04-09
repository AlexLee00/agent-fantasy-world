defmodule AFW.Chain.RLP do
  @moduledoc "Minimal RLP encoder for Ethereum typed transactions."

  def encode(item) when is_list(item) do
    payload = item |> Enum.map(&encode/1) |> IO.iodata_to_binary()
    encode_length(byte_size(payload), 0xC0) <> payload
  end

  def encode(item) when is_integer(item) and item >= 0 do
    item |> integer_to_binary() |> encode()
  end

  def encode(item) when is_binary(item) do
    cond do
      item == <<>> ->
        <<0x80>>

      byte_size(item) == 1 and :binary.first(item) < 0x80 ->
        item

      true ->
        encode_length(byte_size(item), 0x80) <> item
    end
  end

  defp integer_to_binary(0), do: <<>>
  defp integer_to_binary(value), do: :binary.encode_unsigned(value)

  defp encode_length(length, offset) when length < 56 do
    <<offset + length>>
  end

  defp encode_length(length, offset) do
    length_binary = :binary.encode_unsigned(length)
    <<offset + 55 + byte_size(length_binary)>> <> length_binary
  end
end
