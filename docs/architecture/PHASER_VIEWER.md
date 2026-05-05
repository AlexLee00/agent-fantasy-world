# Phaser Viewer

The Phase 1 viewer embeds Phaser 4 inside the Phoenix LiveView dashboard.

## Decision

AFW keeps Phoenix LiveView as the authoritative observer shell and mounts Phaser as a client-side world renderer through a LiveView hook. This avoids a second web app during Phase 1 while still giving the game layer a real-time canvas renderer.

## Current Integration

- Root layout loads Phoenix, Phoenix LiveView, Phaser 4, and `/assets/afw_live.js`.
- `AFWWeb.DashboardLive` provides `zones` and `agents` as JSON data attributes.
- `AethermoorPhaser` reads those attributes, creates a Phaser scene, and updates agent markers on LiveView patches.
- Agent markers are clickable and navigate to `/agents/:id`.
- Agent markers render speech bubbles from the latest action dialogue.
- Action states apply lightweight marker animation: fight pulse, rest breathing, trade sway, talk bubble pulse, and explore step.
- The first Tiled map source is served from `/assets/maps/aethermoor_overview.tmj`.

## Divergence From AI Town

AI Town is useful as a product reference for inspectable AI residents, memory-driven behavior, and a living-map presentation. AFW intentionally diverges at the runtime boundary:

- AFW agents are Elixir/OTP processes, not browser-first simulation objects.
- Settlement state is driven by Base Sepolia contracts and the Settlement Hub, not an app database as the final source of economic truth.
- Phaser is a renderer only. Brain, memory, settlement, and Guardian logic remain server-side.
- LiveView PubSub remains the real-time transport so Guardian/economy/settlement views and the map share one state stream.

## Next Viewer Steps

- Replace generated geometric zones with production Tiled maps per zone.
- Add sprite sheets for agent classes, monsters, NPCs, and action states.
- Replace generated marker animation with sprite-sheet animation.
- Extend dialogue bubbles into multi-agent conversation panels.
- Add replay controls using the Phase 1 replay artifact format.
