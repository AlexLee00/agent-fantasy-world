defmodule AFWWeb.ErrorJSON do
  def render(_template, _assigns), do: %{errors: %{detail: "Something went wrong"}}
end
