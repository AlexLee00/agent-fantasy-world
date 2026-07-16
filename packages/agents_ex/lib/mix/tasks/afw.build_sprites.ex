defmodule Mix.Tasks.Afw.BuildSprites do
  @shortdoc "Runs the SVG -> PNG -> spritesheet pipeline (S2 C-3)"

  @moduledoc """
  Wraps `scripts/build_sprites.sh` (repo root): converts every SVG under
  `assets/art/svg/<category>/` to PNG, enforces the ART_DIRECTION palette
  (TS-2), and packs per-category sheets + Phaser atlases into
  `priv/static/assets/sprites/`.

      mix afw.build_sprites [--skip-palette]
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    root = Path.expand("../..", File.cwd!())
    script = Path.join(root, "scripts/build_sprites.sh")

    unless File.exists?(script) do
      Mix.raise("missing #{script}")
    end

    {_out, status} =
      System.cmd("bash", [script | args],
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    if status != 0 do
      Mix.raise("build_sprites failed with status #{status}")
    end
  end
end
