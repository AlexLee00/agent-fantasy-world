defmodule AFW.Art.BuildSpritesTest do
  # runs the real shell pipeline; skipped when the art toolchain is absent
  use ExUnit.Case, async: false

  @tools ["rsvg-convert", "free-tex-packer-cli", "python3"]

  test "TS-1: pipeline converts fixture SVGs into a sheet + Phaser atlas" do
    if Enum.all?(@tools, &System.find_executable/1) do
      repo_root = Path.expand("../../../../..", __DIR__)
      script = Path.join(repo_root, "scripts/build_sprites.sh")
      src = Path.expand("../../fixtures/art", __DIR__)
      out = Path.join(System.tmp_dir!(), "afw_sprites_#{System.unique_integer([:positive])}")

      try do
        {output, status} =
          System.cmd("bash", [script, "--src", src, "--out", out], stderr_to_stdout: true)

        assert status == 0, "pipeline failed:\n#{output}"
        assert File.exists?(Path.join(out, "hub.png"))

        atlas = Path.join(out, "hub.json") |> File.read!() |> Jason.decode!()
        frames = atlas_frame_names(atlas)

        assert Enum.sort(frames) == ["tile_hub_smoke_a", "tile_hub_smoke_b"]
      after
        File.rm_rf(out)
      end
    else
      IO.puts("skipping build_sprites pipeline test: art toolchain not installed")
      assert true
    end
  end

  # tolerate both Phaser 3 multiatlas ("textures") and hash ("frames") formats
  defp atlas_frame_names(%{"textures" => [texture | _]}) do
    Enum.map(texture["frames"], & &1["filename"])
  end

  defp atlas_frame_names(%{"frames" => frames}) when is_map(frames), do: Map.keys(frames)
  defp atlas_frame_names(%{"frames" => frames}) when is_list(frames) do
    Enum.map(frames, & &1["filename"])
  end
end
