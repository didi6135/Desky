# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-27)
Detailed Phase-1 source: planning-me/PROJECT-PLAN.md

**Core value:** Deploy a personal AI agent on your own Linux server in <10 min, trust it with sensitive data (host-isolated), and rely on it to remember, schedule its own work, and survive failure.
**Current focus:** Phase 1 — Rebrand (Claudify → Desky)

## Current Position

Phase: 1 of 9 (Rebrand)
Plan: 3 of 3 in current phase
Status: Phase complete — Station11 bats round-trip done (rename proven non-breaking)
Last activity: 2026-05-27 — Verified on Station11: identical pass/fail vs baseline e921982; rename breaks nothing

Progress: ██░░░░░░░░ 15% (3/20 plans)

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

**Phase 1 planning (2026-05-27):**
- GitHub repo renamed `didi6135/Claudify` → `didi6135/Desky`; About + 15 SEO topics set. Old name auto-redirects.
- Host migration helper deferred to Phase 2 (its `lib/migrate.sh` absorbs Claudify→Desky); no user-facing window before Phase 9, so no duplication.
- README base rebrand pulled into Phase 1 as 01-03 (repo is already public as Desky); deep docs rewrite + zero-stale-`claudify` gate stay in Phase 3.
- Rename rule: case-respecting token replace; preserve Claude Code engine identity (`claude-code`, `CLAUDE_CONFIG_DIR`, `CLAUDE.md`); exclude `Claudify-<id>` bead IDs and `didi6135/Claudify` URL values (01-02 handles URLs).

### Deferred Issues

- **ISS-001** (.planning/ISSUES.md): `lib/layout.sh` + `lib/service.sh` header comments overclaim mount-namespace isolation the unit body excludes. Reconcile in Phase 3 (docs sync) or Phase 4 (when real isolation lands).
- **ISS-002** (.planning/ISSUES.md): `manifest.bats` + `memory.bats` — 13 stale tests assuming the pre-ADR-0006 nested layout; fail identically at baseline `e921982` (NOT caused by rebrand). `multi-instance.bats` covers the flat layout correctly and passes. Rewrite in Phase 2 (migration touches manifest.sh) or a test-hygiene pass.

### Pending Todos

None yet.

### Blockers/Concerns

- **Carried-in risk:** mount-namespace isolation already failed against AppArmor on Ubuntu 24.04 (old 3.4.5). Container isolation (Phase 4) is the highest-risk item — spike early on Station11 before sinking hours.
- **Doc discrepancy:** doctor check-count cited as both "34-check" and "28/28" — pin the real number at Phase 9 signoff.
- **Pending Station11 round-trip (Phase 1):** bats suite + `shellcheck` could not run on the Windows dev host (no `bats`/`shellcheck`/`jq`). Local `bash -n` + `bash build.sh` are green for 01-01. Run the full suite on Station11 before marking Phase 1 done.

## Session Continuity

Last session: 2026-05-27
Stopped at: Phase 1 (Rebrand) complete — all 3 plans done; Station11 round-trip pending
Resume file: None
