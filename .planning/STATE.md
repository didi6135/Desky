# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-27)
Detailed Phase-1 source: planning-me/PROJECT-PLAN.md

**Core value:** Deploy a personal AI agent on your own Linux server in <10 min, trust it with sensitive data (host-isolated), and rely on it to remember, schedule its own work, and survive failure.
**Current focus:** Phase 1 — Rebrand (Claudify → Desky)

## Current Position

Phase: 1 of 9 (Rebrand)
Plan: Not started
Status: Ready to plan
Last activity: 2026-05-27 — Roadmap created (v1.0 "Good & Secure Base", 9 phases)

Progress: ░░░░░░░░░░ 0% (0/20 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| — | — | — | — |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Several are "Pending" — deferred to the relevant phase's planning step:
- Container runtime (Podman rootless lean) — decide in Phase 4 spike
- Backup encryption (`age` lean) — decide in Phase 5
- Memory = free-form text + FTS5 (no embeddings in P1) — set
- Routines per-instance — set

### Deferred Issues

None yet.

### Pending Todos

None yet.

### Blockers/Concerns

- **Carried-in risk:** mount-namespace isolation already failed against AppArmor on Ubuntu 24.04 (old 3.4.5). Container isolation (Phase 4) is the highest-risk item — spike early on Station11 before sinking hours.
- **Doc discrepancy:** doctor check-count cited as both "34-check" and "28/28" — pin the real number at Phase 9 signoff.

## Session Continuity

Last session: 2026-05-27
Stopped at: Roadmap + state initialized (9 phases, v1.0 milestone)
Resume file: None
