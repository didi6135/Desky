# Phase 5 — Memory + MCP — Task index

Was Phase 4 (memory-track) in the old numbering — promoted to its
own phase on 2026-05-12 alongside the security split.

Memory is the central deliverable of Phase 5: the `claudify-memory`
MCP server (9 tools), `persona.db`, conversation log + FTS5,
operator-controlled facts. Non-memory items from old Phase 4
(DM pairing, reminders, skill marketplace) moved to **[phase-6-skills/](../phase-6-skills/)**.

The research / motivation lives in
[`.planning/research/memory.md`](../../research/memory.md) — read
that **before** starting any 5.x work; it's the source of truth for
the *why* behind every task here.

## Status board

| Task | Title | Status | Estimated | Depends on | Blocks |
|---|---|---|---|---|---|
| 5.0a | [`claudify-memory` MCP server](5.0a-memory-mcp.md) | ⏳ pending | ~3 hr | 3.4.5.1 ✓, 3.4.5.2 ✓ | 5.0b, 5.1, 5.2, all of Phase 6 |
| 5.0b | [Engine wires the MCP](5.0b-engine-memory-wiring.md) | ⏳ pending | ~30 min | 5.0a | 5.1, 5.2 |
| 5.1 | [persona.db + lib/persona.sh + auto-render](5.1-persona.md) | ⏳ pending | ~1 hr | 3.4.5.2 ✓, 5.0a, 5.0b | 5.1.1 |
| 5.1.1 | [`<instance> remember <fact>` command](5.1.1-remember-command.md) | ⏳ pending | ~30 min | 5.1, 3.4.6 | — |
| 5.2 | [Conversation log + FTS5 + `<private>` filter](5.2-conversation-log.md) | ⏳ pending | ~1 hr | 5.0a, 5.0b | 6.x skills that query past chats |

**Total estimated effort:** ~6 hr across 5 tasks.

## Order (load-bearing)

```
5.0a → 5.0b → 5.1 → 5.1.1
              └──→ 5.2 (after 5.0b; parallel to 5.1+5.1.1)
```

5.0a → 5.0b ships the substrate (MCP server + engine wiring) before
anything else. After 5.0b lands, 5.1 (persona) and 5.2 (conversation
log) can run in parallel.

## What lands at the end of Phase 5

- A working MCP server in `src/mcp/memory/` exposing 9 tools
- `claude mcp list` shows `claudify-memory` after install
- `data/_persona/persona.db` with operator's name + timezone + language + working hours, auto-rendered into `CLAUDE.md` via the marker-bracketed block (3.4.5.2's engine_apply_persona)
- `<instance> remember "<key>" "<value>"` operator command — explicit, no auto-extract
- `data/_conversations/messages.db` with FTS5 index, `<private>` stripped, `<no-log>` honored
- The bot, asked *"what did we talk about yesterday?"*, can answer accurately

## Phase rename note

Old numbering: `phase-4-capabilities.md` had memory + skills items inline. New numbering: memory items live here in `phase-5-mem-mcp/`, skills items moved to `phase-6-skills/`. Cross-refs renumbered:

- `4.0a` → `5.0a`
- `4.0b` → `5.0b`
- `4.1` → `5.1`
- `4.1.1` → `5.1.1`
- `4.4` (conversation log) → `5.2`

Phase 6 (skills) renumbered `4.2/4.3/4.5/4.6` → `6.1/6.2/6.3/6.4`.
The old Phase 5 (secrets/cost/audit) moves to Phase 7 in the
ROADMAP.
