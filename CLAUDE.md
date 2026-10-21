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

## Rules for the agent roster

- Keep the roster small (aim for ~8-12 agents, never dozens).
- Add a new agent only when an existing one is clearly overloaded, covers two unrelated areas, or a separate agent would be cheaper or better (e.g. a distinct recurring area such as audio, data/persistence, shop/monetization).
- Before adding one, check that no existing agent can take the job, and tell the user what was added and why.
- Prefer merging or removing agents that are rarely used.
- Plans for big prompts go in `PLAN.md`; each new session reads it first.
