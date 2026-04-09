defmodule AFW.Brain.Interface do
  @moduledoc "Behaviour for pluggable AFW brain providers."

  @callback decide(context :: map()) :: {:ok, map()} | {:error, term()}
end
