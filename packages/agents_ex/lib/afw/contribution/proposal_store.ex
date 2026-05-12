defmodule AFW.Contribution.ProposalStore do
  @moduledoc """
  Stores Contribution Agent reward proposals for multisig review.

  Phase 2 treats reward calculation as an auditable proposal first. Optional
  Settlement Hub submission can be enabled after the multisig role path is
  verified for the deployed distribution pools.
  """

  use GenServer

  @table :afw_contribution_proposals

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    ensure_table!()
    path = Keyword.get(opts, :path, Application.get_env(:afw, :contribution_proposal_path))
    prepare_path(path)
    {:ok, %{path: path}}
  end

  def save(proposal) when is_map(proposal) do
    ensure_table!()
    :ets.insert(@table, {proposal.id, proposal})
    persist(proposal)
    {:ok, proposal}
  end

  def latest(limit \\ 10) do
    ensure_table!()

    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, proposal} -> proposal end)
    |> Enum.sort_by(&DateTime.to_unix(&1.createdAt, :microsecond), :desc)
    |> Enum.take(limit)
  end

  def clear_all do
    ensure_table!()
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def handle_cast({:persist, proposal}, %{path: path} = state) do
    if usable_path?(path) do
      File.mkdir_p!(path)
      file = Path.join(path, "#{proposal.id}.json")
      File.write!(file, Jason.encode_to_iodata!(proposal, pretty: true))
    end

    {:noreply, state}
  end

  defp persist(proposal) do
    if Process.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, {:persist, proposal})
    end
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        @table
    end
  end

  defp prepare_path(path) do
    if usable_path?(path), do: File.mkdir_p!(path)
  end

  defp usable_path?(path), do: is_binary(path) and String.trim(path) != ""
end
