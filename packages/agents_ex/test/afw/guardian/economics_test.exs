defmodule AFW.Guardian.EconomicsTest do
  use ExUnit.Case, async: true

  test "treasury view selects next threshold and remaining amount" do
    view = AFW.Guardian.Economics.treasury_view(2_000 * 1_000_000_000_000_000_000, [])
    assert view.next_threshold == "ZONE"
    assert view.remaining_to_next == 3_000 * 1_000_000_000_000_000_000
  end
end
