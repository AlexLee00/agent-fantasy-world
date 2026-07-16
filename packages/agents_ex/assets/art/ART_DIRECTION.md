# AFW Art Direction — 32px Pixel Art (v1)

> Status: v1 — approved 2026-07-16 (S2 C-2).
> This document is the single source of truth for AFW's visual identity and
> MUST be included verbatim in every asset-generation prompt.

## 1. Core Identity

Warm, high-contrast 32px pixel art. Saturated colors, minimal outlines,
readable silhouettes at 1x and 2x display scale. Reference mood:
Eastward / CrossCode — cozy but adventurous, never grimdark.

Non-negotiables:

- Grid: **32×32 px per tile**. Characters occupy one tile footprint
  (taller sprites may extend 8px into the tile above, e.g. 32×40 is allowed
  for buildings/NPCs only, never for agent walk cycles in v1).
- Outlines: none on terrain; selective dark outline (`#2A2119`) only where a
  sprite must separate from busy ground (characters, interactive props).
- Contrast: every sprite must read on both its region ground colors
  (checker test against the two ground tones of its home region).
- Light source: top-left, single. Shadows are color-shifted (darker, cooler),
  never pure black. No dithering gradients larger than 2px steps.
- No anti-aliasing, no semi-transparent pixels (alpha is 0 or 255).

## 2. SVG Authoring Rules (pipeline contract)

SVG is the SSOT; PNG/sheets are build artifacts (`scripts/build_sprites.sh`).

- `viewBox="0 0 32 32"` (or `0 0 W H` for multi-tile props, W/H multiples of 32).
- **1 pixel = 1 `<rect>`** of size 1×1 aligned to integer coordinates.
  No paths, circles, strokes, gradients, filters, masks, or transforms.
- Fill colors MUST come from §3 palettes (exact hex, uppercase). Any other
  color fails the palette check (TS-2).
- One sprite per file. File naming: `<category>_<name>[_<dir>_<frame>].svg`
  e.g. `agent_warrior_down_1.svg`, `tile_lumenveil_grass_a.svg`,
  `building_hub_tavern.svg`.
- Directory layout:
  `assets/art/svg/{hub,lumenveil,graymarch,embervault,voidreach,agents,ui}/`.
- Every file starts with a comment line:
  `<!-- AFW 32px | palette: <region> | ART_DIRECTION v1 -->`.

## 3. Palettes (hard-coded, exhaustive)

### 3.0 Common (allowed everywhere)

| Role | Hex |
|---|---|
| Ink outline | `#2A2119` |
| Cream highlight | `#F2E6C8` |
| Deep water | `#2E5E8C` |
| Water light | `#4E86B8` |
| Wood dark | `#6E4A2E` |
| Wood light | `#9A6B42` |
| Stone dark | `#5C5850` |
| Stone light | `#8C877C` |

### 3.1 Havenmoor (HUB — warm sandstone town)

`#D9BE8C` plaza sand · `#B8935E` packed earth · `#B85C40` roof terracotta ·
`#8A5C36` timber · `#9C9484` wall stone · `#C24E4E` market red ·
`#4E7AA6` market blue · `#E8C86A` lantern gold

### 3.2 Lumenveil (SAFE — spring meadow/forest)

`#74B356` grass · `#4E8A3E` grass shade · `#A8CE72` grass light ·
`#3F7A46` foliage · `#2E5C38` foliage shade · `#E3C25C` wheat accent ·
`#C2A15C` dirt path · `#8FBF8A` moss

### 3.3 Graymarch (MEDIUM — misty marsh)

`#7A8F7D` marsh grass · `#5C7263` marsh shade · `#9AAA92` fog light ·
`#48594E` bog dark · `#6E8A9E` cold water · `#B4C2AC` reed light ·
`#8A7A5C` dead wood · `#A6B8C2` mist accent

### 3.4 Embervault (DANGER — volcanic)

`#9E4A32` scorched earth · `#6E3226` basalt dark · `#C26936` ember ·
`#E08A3C` lava glow · `#F2B03E` lava bright · `#7A4A3A` ash brown ·
`#4A2E28` obsidian · `#D9C2A6` bone pale

### 3.5 Voidreach (EXTREME — void wastes)

`#5A4A7E` void stone · `#3E3258` void deep · `#8A6BB1` arcane ·
`#C08AE0` arcane bright · `#2A2340` abyss · `#493E66` shadow slate ·
`#6E86A6` pale rune · `#E0D9F2` starlight

### 3.6 UI (icons/markers only)

`#E8C86A` gold · `#B84A4A` alert red · `#4E9E6E` confirm green ·
`#4E7AA6` info blue · `#F2E6C8` parchment · `#2A2119` ink

Rule: a region asset may use its own region palette + Common. Agents/UI use
Common + UI + at most 3 colors of their class accent row (defined in v1.1
when agent batches start). Never mix two region palettes in one sprite.

## 4. Category Specs (v1 batches)

| Category | Size | Count (v1) | Notes |
|---|---|---|---|
| Terrain tiles | 32×32 | 16/region | 2 ground variants, edges, water, road/bridge, 4 deco |
| Buildings (hub) | 64×64 or 64×96 | 8 | tavern, market, smithy, quest board, bank, gate, houses ×2 |
| NPCs (hub) | 32×40 | 8 | merchant, innkeep, smith, board keeper, guard ×2, elder, courier |
| Agents | 32×32/frame | 5 classes × 16 frames | 4 dir × 3 walk + fight/rest/trade/talk poses |
| Monsters | 32×32 | 2 (Lumenveil) | slime, wolf variants |
| UI icons | 16×16 | 30 | quest !/?, skill, faction badges, HP/resource pips |

Agent sheet frame order (fixed): `down1 down2 down3 left1..3 right1..3 up1..3
fight rest trade talk` — 16 frames, packed left-to-right, single row per class.

## 5. Quality Gates

1. **Palette check (TS-2)**: every PNG pixel ∈ allowed palette for its
   category. Enforced by the sprite build's palette checker.
2. **Silhouette check**: sprite recognizable when filled 100% with ink color
   (manual, part of preview review).
3. **Master preview gate (TS-4)**: each batch renders `preview_<batch>.png`
   (all sprites on both ground tones, 2x scale). Master approves before the
   batch enters the packed sheets. Rejected sprites: fix the SVG, regenerate.

## 6. License

All assets are original work, released as **CC0** (public domain dedication),
consistent with the project's open-source guide. No third-party asset may be
traced or color-swapped.
