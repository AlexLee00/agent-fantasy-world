defmodule AFW.Economy.Constants do
  @moduledoc "Shared item and status identifiers used by the Elixir runtime."

  @one_soul 1_000_000_000_000_000_000

  def one_soul, do: @one_soul
  def rest_item_name, do: "Basic Health Potion"
  def resting_status_id, do: 3
  def alive_status_id, do: 1
end
