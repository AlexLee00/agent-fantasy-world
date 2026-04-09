defmodule AFW.Chain.Contracts do
  @moduledoc "Central contract address registry loaded from runtime config."

  def all do
    Application.fetch_env!(:afw, :contracts)
  end

  def get(key) when is_atom(key) do
    all()[key]
  end
end
