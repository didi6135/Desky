# Phase 4 — Capabilities — SPLIT 2026-05-12

> **This doc is now a pointer.** The original Phase 4 ("Capabilities")
> covered memory, persona, conversation log, DM pairing, reminders,
> skill marketplace. On 2026-05-12 it was split along the natural
> seam between **memory infrastructure** (now Phase 5) and **skills
> & user management** (now Phase 6). Security hardening (was 3.6)
> was simultaneously promoted to its own Phase 4.

## Where the content moved

| Old task | What | New location |
|---|---|---|
| 4.0a | `claudify-memory` MCP server | [`phase-5-mem-mcp/5.0a-memory-mcp.md`](phase-5-mem-mcp/5.0a-memory-mcp.md) |
| 4.0b | Engine wires the MCP | [`phase-5-mem-mcp/5.0b-engine-memory-wiring.md`](phase-5-mem-mcp/5.0b-engine-memory-wiring.md) |
| 4.1 | persona.db + auto-render | [`phase-5-mem-mcp/5.1-persona.md`](phase-5-mem-mcp/5.1-persona.md) |
| 4.1.1 | `<instance> remember <fact>` | [`phase-5-mem-mcp/5.1.1-remember-command.md`](phase-5-mem-mcp/5.1.1-remember-command.md) |
| 4.4 | Conversation log + FTS5 | [`phase-5-mem-mcp/5.2-conversation-log.md`](phase-5-mem-mcp/5.2-conversation-log.md) |
| 4.2 | DM pairing flow | [`phase-6-skills/6.1-dm-pairing.md`](phase-6-skills/6.1-dm-pairing.md) |
| 4.3 | First real skill: reminders | [`phase-6-skills/6.2-reminders-skill.md`](phase-6-skills/6.2-reminders-skill.md) |
| 4.5 | Skill marketplace + install UX | [`phase-6-skills/6.3-skill-marketplace.md`](phase-6-skills/6.3-skill-marketplace.md) |
| 4.6 | `<instance> skill new` template | [`phase-6-skills/6.4-skill-template.md`](phase-6-skills/6.4-skill-template.md) |

## Status boards

- [Phase 5 — Memory + MCP — task index](phase-5-mem-mcp/README.md)
- [Phase 6 — Skills & user management — task index](phase-6-skills/README.md)

## Why the split

Before the split, "memory" and "skills" lived in one doc as Phase 4.
That meant the operator couldn't easily track *which* part of Phase 4
was in progress — the substrate (memory MCP) and the surface (skills
that use it) advance at different rates. Splitting clarifies what's
ready, what's blocked, and where each piece of work lives.

The end-state targets, dependency notes, and out-of-scope items from
the original Phase 4 doc are now distributed across the two new
folder READMEs.
