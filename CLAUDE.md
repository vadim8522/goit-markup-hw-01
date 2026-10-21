# Roblox project - delegation guide

The game is being fully reworked: islands, UI, economy, custom Blender models and animations.
Specialist subagents live in `.claude/agents/`. Delegate by area:

- `architect` (opus): architecture, planning big changes, hard cross-cutting bugs
- `gameplay` (sonnet): Luau client/server systems, remotes, ordinary bugs
- `economy` (opus): currencies, prices, balance, progression, monetization
- `ui-designer` (sonnet): all UI/UX
- `world-builder` (sonnet): islands, terrain, lighting, environment performance
- `blender-assets` (sonnet): custom models and export pipeline
- `animator` (sonnet): animations, rigs, VFX
- `quick-fixes` (haiku): trivial chores in any area
- `roblox-dev:roblox-reviewer`: read-only audit of security, DataStores, performance

For large work, start with `architect` for a plan, then hand steps to the specialists.
