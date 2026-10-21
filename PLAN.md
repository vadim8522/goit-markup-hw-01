# PLAN

Living plan for the Roblox rework (islands, UI, economy, Blender models, animations).
Each new session reads this first. Big prompts get an audit and a plan here before any code changes.

## Standing requirements

### Seasonal events ("event worlds")

Events reuse the same islands with different decorations; they are layers, not rebuilt worlds.

- **Permanent vs swappable.** Every island has a permanent layer (terrain, bridges, collisions, routes, eggs, leaderboards, shop) and a decoration layer (trees, lamps, banners, props, sky, lighting, particles).
- **Anchors.** Decoration spots are named invisible anchors (`Deco_*`, tagged with CollectionService). A theme places props at anchors; it never edits the island.
- **Theme sets.** `Themes/<EventName>/<IslandName>` holds the props for each event. Removing a theme returns the island to normal.
- **One switch.** A single `LiveEvent` (theme) module on the server knows the active event (by date or manual flag) and applies it everywhere: decorations, lighting/sky/music/particles, UI styling and texts, event eggs, shop items and rewards. UI, islands, eggs and shop read the active theme from it and have no switches of their own.
- **Data, not code.** Event configs (dates, colors, rewards, event egg tables, prices) live in data tables. Adding an event is a config change plus a decoration set.
- **Persistence.** Event currencies and pets get their own slot and a versioned schema in saved data so later events need no migration.
- **Models.** Generated models (e.g. turrets) take a `THEME` parameter where useful, so a themed variant is one script run, not new modelling.

| Work | Agent | When |
|---|---|---|
| Island structure with anchors | `world-builder` | during the island rework |
| `LiveEvent` module and theme switch | `architect` + `gameplay` | when the core is laid down |
| Event decoration sets | `blender-assets` + `world-builder` | per event |
| Event eggs, pets, prices | `economy` | per event |

## Phases

_To be filled after the project audit (needs the Roblox project connected via Rojo or Studio MCP)._
