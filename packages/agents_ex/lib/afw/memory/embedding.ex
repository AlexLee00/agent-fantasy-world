defmodule AFW.Memory.Embedding do
  @moduledoc """
  Embedding adapter for memory retrieval.

  Ollama is used when explicitly configured. A deterministic local vector is
  always available as a fallback so tests and demos do not depend on a local
  model being installed.
  """

  @dimensions 32

  def embed(text) do
    provider = Application.get_env(:afw, :memory_embedding_provider, "local")

    case provider do
      "ollama" -> ollama_embed(text) || local_embed(text)
      :ollama -> ollama_embed(text) || local_embed(text)
      _ -> local_embed(text)
    end
  end

  def cosine(left, right) when is_list(left) and is_list(right) and left != [] and right != [] do
    pairs = Enum.zip(left, right)
    dot = Enum.reduce(pairs, 0.0, fn {a, b}, acc -> acc + a * b end)
    left_norm = norm(left)
    right_norm = norm(right)

    if left_norm == 0.0 or right_norm == 0.0 do
      0.0
    else
      dot / (left_norm * right_norm)
    end
  end

  def cosine(_left, _right), do: 0.0

  defp ollama_embed(text) do
    host = Application.get_env(:afw, :ollama_host, "http://localhost:11434")
    model = Application.get_env(:afw, :memory_embedding_model, "embeddinggemma")

    case Req.post("#{host}/api/embed",
           json: %{model: model, input: to_string(text)},
           receive_timeout: 5_000
         ) do
      {:ok, %{status: status, body: %{"embeddings" => [embedding | _]}}}
      when status in 200..299 and is_list(embedding) ->
        normalize_vector(embedding)

      _ ->
        nil
    end
  rescue
    _ -> nil
  catch
    :exit, _ -> nil
  end

  defp local_embed(text) do
    vector =
      text
      |> tokenize()
      |> Enum.reduce(List.duplicate(0.0, @dimensions), fn token, acc ->
        index = :erlang.phash2(token, @dimensions)
        weight = 1.0 + min(String.length(token), 12) / 12.0
        List.update_at(acc, index, &(&1 + weight))
      end)

    normalize_vector(vector)
  end

  defp tokenize(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_#]+/, " ")
    |> String.split(" ", trim: true)
    |> Enum.reject(&(String.length(&1) < 2))
  end

  defp normalize_vector(vector) do
    vector = Enum.map(vector, &to_float/1)
    vector_norm = norm(vector)

    if vector_norm == 0.0 do
      vector
    else
      Enum.map(vector, &Float.round(&1 / vector_norm, 6))
    end
  end

  defp norm(vector) do
    vector
    |> Enum.reduce(0.0, fn value, acc -> acc + value * value end)
    |> :math.sqrt()
  end

  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value / 1
  defp to_float(_value), do: 0.0
end
