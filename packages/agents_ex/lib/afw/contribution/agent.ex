defmodule AFW.Contribution.Agent do
  @moduledoc "Epoch-based Contribution Agent that evaluates GitHub and on-chain contributions."

  use GenServer

  alias AFW.Contribution.{GitHub, OnChain, Proposer, Scorer}

  @epoch_interval 7 * 24 * 60 * 60 * 1000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def evaluate_now do
    GenServer.cast(__MODULE__, :evaluate)
  end

  def evaluate_once(epoch \\ 1) do
    github = GitHub.fetch_metrics()
    on_chain = OnChain.fetch_metrics()
    scores = Scorer.score(%{github: github, on_chain: on_chain})
    proposal = Proposer.submit_epoch_rewards(epoch, scores)
    {scores, proposal}
  end

  @impl true
  def init(state) do
    schedule()
    {:ok, Map.put(state, :epoch, 1)}
  end

  @impl true
  def handle_cast(:evaluate, state) do
    {scores, proposal} = evaluate_once(state.epoch)

    Phoenix.PubSub.broadcast(
      AFW.PubSub,
      "guardian",
      {:contribution_epoch, state.epoch, scores, proposal}
    )

    {:noreply, %{state | epoch: state.epoch + 1}}
  end

  @impl true
  def handle_info(:evaluate, state) do
    {:noreply, next_state} = handle_cast(:evaluate, state)
    schedule()
    {:noreply, next_state}
  end

  defp schedule do
    Process.send_after(self(), :evaluate, @epoch_interval)
  end
end
