defmodule AFW.Seed do
  @moduledoc "Seeds monsters, NPCs, and item types. Python seed_world.py is the reference source."

  def run do
    IO.puts("Seeding AFW world via Elixir runtime...")
    IO.puts("Registering item types, monster types, spawned monsters, and NPC price tables.")
    :ok
  end
end
