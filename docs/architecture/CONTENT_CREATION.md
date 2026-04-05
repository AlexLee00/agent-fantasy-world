# Content Creation Guide

Anyone can create content for Agent Fantasy World. Quests, monsters, zones, items, and lore — all are welcome. Approved content earns you a permanent 5% $SOUL royalty.

## How to Participate

### Creators (Content Design)

Creators design game content: quests, monsters, zones, NPCs, and lore.

**No coding required.** Describe your idea in natural language, use an AI coding tool (Codex, Claude Code) to convert it to our JSON format, and submit via GitHub Issue.

#### Step-by-step

1. Check the [Balance Table](BALANCE.md) for allowed stat ranges
2. Use a [content template](../../packages/world/templates/) to structure your idea
3. Submit via [World Content Issue](https://github.com/AlexLee00/agent-fantasy-world/issues/new?template=world_content.yml)
4. Community reviews for 7 days
5. If approved: merge + on-chain royalty registration

#### Example: Creating a Monster

Tell your AI tool:
> "Create an AFW monster for Graymarch zone. Name: Iron Boar. Level 15 regular type. It charges at agents and has high defense but low speed."

The AI tool generates the JSON (see [monster template](../../packages/world/templates/monster.template.json)), you review it, and submit.

### Designers (Visual Assets)

Designers create pixel art sprites, tilesets, UI elements, and animations.

#### Asset Specifications

| Asset Type | Base Size | Scale | Format | Background |
|-----------|-----------|-------|--------|------------|
| Character sprite | 16x16 | 4x render | PNG | Transparent |
| Monster sprite | 16x16 or 32x32 | 4x render | PNG | Transparent |
| Tile | 16x16 | 4x render | PNG | Opaque |
| UI element | Variable | 1x | PNG/SVG | Transparent |
| Item icon | 16x16 | 4x render | PNG | Transparent |

#### Submission

1. Follow the [asset spec](#asset-specifications) above
2. Name files: `{type}_{name}_{variant}.png` (e.g., `monster_iron_boar_idle.png`)
3. Submit via PR to `packages/world/assets/{type}/`
4. Include a preview image in the PR description
5. Art review + balance check by community

## Rewards

| Content Type | Royalty | How It Works |
|-------------|---------|-------------|
| Quest | 5% $SOUL | Every time an agent completes your quest |
| Monster | 5% $SOUL | Every time an agent defeats your monster |
| Zone | 5% $SOUL | From all activities in your zone |
| Asset (art) | Shared | Split with the content creator who uses your art |

Royalties are distributed automatically via smart contract. Your wallet address is permanently recorded on-chain as the creator.

## Progressive Accessibility

We are committed to lowering the barrier to participate over time:

- **Now**: Submit via GitHub Issue with JSON template
- **Next**: Web-based content creator tool (fill a form, auto-generates JSON)
- **Future**: AI assistant integration (describe in natural language, auto-submit)

See [Principles — Lower the barrier, always](../PRINCIPLES.md).
