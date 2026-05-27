# Phase 6 — Skills & user management — Task index

Was the skills-track inside old Phase 4 — split out on 2026-05-12 so
memory (Phase 5) and skills (Phase 6) are first-class trackable items.

The vision lives in [`.planning/phases/phase-4-capabilities.md`](../phase-4-capabilities.md)
(legacy overview — keep until Phase 6 closes) and the skill author
contract lives in [`docs/skills.md`](../../../docs/skills.md).

## Status board

| Task | Title | Status | Estimated | Depends on | Blocks |
|---|---|---|---|---|---|
| 6.1 | [DM pairing flow](6.1-dm-pairing.md) | ⏳ pending | ~1 hr | 3.4.5 ✓, 3.4.5.1 ✓ | — |
| 6.2 | [First real skill: `reminders`](6.2-reminders-skill.md) | ⏳ pending | ~2 hr | 3.4.5.1 ✓, 5.1, 5.0a, 5.0b | 6.3 (canonical example) |
| 6.3 | [Skill marketplace install UX](6.3-skill-marketplace.md) | ⏳ pending | ~1.5 hr | 3.4.6, 6.2 | 6.4 |
| 6.4 | [`<instance> skill new` template generator](6.4-skill-template.md) | ⏳ pending | ~1 hr | 6.3 | — |

**Total estimated effort:** ~5.5 hr across 4 tasks.

## Order

```
6.1 (parallel-able with 5.x)
6.2 — needs Phase 5 closed (persona + memory MCP)
6.3 — after 6.2 (reminders is the canonical install target)
6.4 — after 6.3 (template generator uses the install flow)
```

6.1 (DM pairing) doesn't touch memory — it can land anytime after
Phase 3 closes, in parallel with Phase 5.

## What lands at the end of Phase 6

- Operator can pair new Telegram users via `/approve <code>` instead of hand-editing `access.json`
- A working `reminders` skill ships with Claudify — the operator can `client-a skill install reminders` and start saving reminders today
- Third-party skills installable via `<instance> skill install <id>` from a curated `claudify-skills` GitHub org
- Skill authors run `<instance> skill new <id>` to bootstrap a new skill in 60 seconds

## Phase rename note

Old numbering: inline in `phase-4-capabilities.md` as 4.2, 4.3, 4.5,
4.6. New numbering renumbers to:

- `4.2` → `6.1` (DM pairing)
- `4.3` → `6.2` (reminders skill)
- `4.5` → `6.3` (skill marketplace)
- `4.6` → `6.4` (skill template)

Memory-track items from old Phase 4 (`4.0a/4.0b/4.1/4.1.1/4.4`)
moved to `phase-5-mem-mcp/`. The old Phase 5
(secrets/cost/audit/observability) moves to Phase 7 in the ROADMAP.
