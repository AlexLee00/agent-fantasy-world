defmodule AFWWeb.ErrorHTML do
  use AFWWeb, :html

  def render(_template, _assigns), do: "Something went wrong"
end
