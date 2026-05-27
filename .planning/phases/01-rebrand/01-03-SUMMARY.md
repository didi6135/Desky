---
phase: 01-rebrand
plan: 03
subsystem: docs
tags: [readme, rebrand, multi-instance, documentation]

requires:
  - phase: 01-01
    provides: Desky-renamed paths, service unit, layout
  - phase: 01-02
    provides: didi6135/Desky URLs, version, blocklist
provides:
  - Desky-branded, multi-instance-accurate README front page
affects: [03-docs-sync]

tech-stack:
  added: []
  patterns:
    - "Document only shipped reality; defer future-phase claims explicitly"

key-files:
  created:
    - .planning/ISSUES.md
  modified:
    - README.md

key-decisions:
  - "Isolation described honestly as systemd Tier-1 host hardening, not container/cross-instance isolation"
  - "doctor count written as 'a battery of health checks' (28-vs-34 unresolved until Phase 9)"

issues-created: [ISS-001]

duration: ~12 min
completed: 2026-05-27
---

# Phase 1 Plan 03: README Refresh Summary

**README rewritten from the stale Claudify single-instance design to the real Desky multi-instance behavior — `~/.desky-<name>/` tree, `~/.local/bin/<name>` command, `desky-<name>.service`, honest systemd-hardening isolation note, `didi6135/Desky` URLs — verified against the code and human-approved.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-05-27
- **Tasks:** 1 auto + 1 human-verify checkpoint (approved)
- **Files modified:** 2 (README.md, ISSUES.md created)

## Accomplishments

- Rebranded README to Desky with a positioning tagline (self-hosted personal AI assistant on your own Linux server, reachable from Telegram).
- Corrected the architecture from single-instance to multi-instance: default name = Linux username, `--name <instance>` for more; full `~/.desky-<name>/` tree verified against `lib/layout.sh`; `~/.desky-registry.json` side-car; per-instance `desky.json` manifest.
- Led with the `~/.local/bin/<name>` personal command (subcommands verified against `lib/personal-cmd.sh`); raw `systemctl --user desky-<name>` shown as fallback.
- Replaced the wrong `claude-telegram.service` with `desky-<name>.service`; corrected the resume path to `~/.desky-<name>/.install-partial`.
- Wrote an honest isolation note (systemd Tier-1 host hardening, not cross-instance/container isolation) per the accuracy guardrails.
- All URLs → `didi6135/Desky`; fixed a dead `.planning/conventions.md` link → `.planning/codebase/CONVENTIONS.md`; dropped the non-existent `.planning/decisions/` link.

## Task Commits

1. **Task 1: Rewrite README** — `41a19bb` (docs)

## Files Created/Modified

- `README.md` — full rewrite (Desky multi-instance)
- `.planning/ISSUES.md` — created; logs ISS-001

## Decisions Made

- **Honest isolation framing:** the shipped unit excludes mount-namespace directives (AppArmor failure), so the README describes systemd Tier-1 *host* hardening and explicitly defers container isolation to the roadmap — no overclaim.
- **No doctor count:** the 28-vs-34 discrepancy is unresolved (Phase 9), and `doctor.sh` has no clean machine-readable count, so the README says "a battery of health checks."

## Deviations from Plan

None to the plan's tasks. One enhancement logged:

### Deferred Enhancements

Logged to `.planning/ISSUES.md`:
- **ISS-001:** `lib/layout.sh` + `lib/service.sh` header comments overclaim mount-namespace isolation that the unit body explicitly excludes — reconcile in Phase 3 docs sync (or Phase 4 when real isolation lands). Discovered while verifying the README isolation note.

## Issues Encountered

- **Pending Station11 verification (phase-level):** the bats suite + `shellcheck` for 01-01/01-02 still need a Station11 round-trip before Phase 1 is fully signed off. 01-03 is docs-only (no test impact). Local evidence for the code plans: `bash -n` all pass, `bash build.sh` green, install URL 200.

## Next Phase Readiness

**Phase 1 (Rebrand) complete** — code, paths, service, registry, public URLs, and README all say Desky. Engine identity preserved. Only the historical CHANGELOG header retains "Claudify" (Phase 3) and the immutable `Claudify-e4a` bead IDs remain.

**Caveat:** run the deferred Station11 bats + shellcheck round-trip to fully close the phase's verification.

Next: Phase 2 (Migration) — `lib/migrate.sh` to migrate existing installs (pre-3.4.5 `~/.claudify/` and 3.4.5+ `~/.claudify-*/`) to the Desky layout. Carry forward the 01-01 migration note (dir, service, manifest filename + `.claudify_version` key, PATH marker, persona markers all changed).
