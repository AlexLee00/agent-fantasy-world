defmodule AFW.Tier4.NodeServer do
  @moduledoc "HTTP inference server for Tier 4 community node operators."

  use Plug.Router

  alias AFW.Brain

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  def start_link(opts \\ []) do
    port = Keyword.get(opts, :port, Application.get_env(:afw, :tier4_node_port, 18_791))
    Plug.Cowboy.http(__MODULE__, [], port: port)
  end

  def child_spec(opts) do
    port = Keyword.get(opts, :port, Application.get_env(:afw, :tier4_node_port, 18_791))

    Plug.Cowboy.child_spec(
      scheme: :http,
      plug: __MODULE__,
      options: [port: port]
    )
  end

  get "/health" do
    json(conn, 200, %{
      status: "ok",
      service: "afw-tier4-node",
      backend: backend_name()
    })
  end

  post "/infer" do
    context = request_context(conn.body_params)

    case decide(context) do
      {:ok, action} ->
        json(conn, 200, %{
          action: action,
          node: %{
            service: "afw-tier4-node",
            backend: backend_name()
          }
        })

      {:error, reason} ->
        json(conn, 502, %{
          error: "inference_failed",
          reason: inspect(reason),
          node: %{service: "afw-tier4-node", backend: backend_name()}
        })
    end
  end

  match _ do
    json(conn, 404, %{error: "not_found"})
  end

  def decide(context) do
    backend_name()
    |> provider_module()
    |> Brain.Interface.decide_with_fallback(context)
  end

  def infer_url do
    case Application.get_env(:afw, :tier4_node_public_url, "") do
      "" -> "http://127.0.0.1:#{Application.get_env(:afw, :tier4_node_port, 18_791)}/infer"
      url -> String.trim_trailing(url, "/") <> "/infer"
    end
  end

  defp request_context(%{"prompt" => prompt} = body) do
    %{
      prompt: prompt,
      event:
        normalize_event(
          Map.get(body, "event", %{"target" => Map.get(body, "target", "aethermoor")})
        )
    }
  end

  defp request_context(_body) do
    %{
      prompt: "Choose one safe AFW action.",
      event: %{"target" => "aethermoor"}
    }
  end

  defp normalize_event(%{"type" => type, "target" => target}) do
    %{type: normalize_event_type(type), target: target}
  end

  defp normalize_event(%{"target" => target}), do: %{target: target}

  defp normalize_event(%{type: _type, target: _target} = event), do: event
  defp normalize_event(%{target: _target} = event), do: event
  defp normalize_event(_event), do: %{target: "aethermoor"}

  defp normalize_event_type("survival"), do: :survival
  defp normalize_event_type("trade"), do: :trade
  defp normalize_event_type("npc"), do: :npc
  defp normalize_event_type("monster"), do: :monster
  defp normalize_event_type(value) when is_atom(value), do: value
  defp normalize_event_type(_value), do: :explore

  defp backend_name do
    Application.get_env(:afw, :tier4_node_backend, "afw-basic")
  end

  defp provider_module("afw-basic"), do: Brain.AFWBasic
  defp provider_module("anthropic"), do: Brain.Anthropic
  defp provider_module("openai"), do: Brain.OpenAI
  defp provider_module("openclaw"), do: Brain.OpenClaw
  defp provider_module("claude-code"), do: Brain.ClaudeCode
  defp provider_module("node"), do: Brain.AFWBasic
  defp provider_module(_provider), do: Brain.AFWBasic

  defp json(conn, status, payload) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(payload))
  end
end
