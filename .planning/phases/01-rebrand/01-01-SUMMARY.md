---
phase: 01-rebrand
plan: 01
subsystem: infra
tags: [bash, rename, systemd, manifest, rebrand]

requires: []
provides:
  - Desky-branded substrate (paths, layout, service unit, registry, manifest)
  - DESKY_* env-var prefixes across all lib modules
  - MANIFEST_VERSION 2 (desky.json + .desky_version schema)
affects: [02-public-identity, 03-readme, migration]

tech-stack:
  added: []
  patterns:
    - "Case-distinct three-token rename, exclusions restored post-pass"
    - "Engine identity isolated from brand strings (Invariant 1)"

key-files:
  created: []
  modified:
    - lib/layout.sh
    - lib/service.sh
    - lib/manifest.sh
    - lib/engine.sh
    - lib/personal-cmd.sh
    - dist/install.sh

key-decisions:
  - "MANIFEST_VERSION bumped 1->2 (manifest filename + version-key schema change)"
  - "shellcheck + bats suite deferred to Station11 round-trip (not on Windows dev host)"

issues-created: []

duration: ~15 min
completed: 2026-05-27
---

# Phase 1 Plan 01: Internal Code + Test Rename Summary

**Renamed the Claudify substrate to Desky across 26 code/test files (paths, systemd unit, registry, manifest filename + version key, env prefixes, markers, brand strings); `dist/` rebuilt; engine identity preserved byte-for-byte; tree parses clean. Full bats suite + shellcheck pending a Station11 round-trip.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-05-27
- **Tasks:** 2/2
- **Files modified:** 28 (26 sources + dist/install.sh + CHANGELOG.md)

## Accomplishments

- Case-distinct three-token replace (`CLAUDIFY`/`Claudify`/`claudify` → `DESKY`/`Desky`/`desky`) across `lib/`, root scripts, `src/package.json`, and the bash test suite — 26 files.
- On-disk shapes renamed: `~/.desky-<name>/`, `~/.desky-registry.json`, `desky-<name>.service`, per-instance `desky.json` (+ `.desky_version` key), `DESKY_*` env prefixes, PATH + persona markers, `/tmp/desky-install-*.log`.
- `MANIFEST_VERSION` bumped 1 → 2 for the manifest schema change.
- Claude Code engine identity (`claude-code`, `CLAUDE_CONFIG_DIR`, `.claude.json`, `CLAUDE.md`, `claude mcp`) preserved — baseline 58 occurrences unchanged.
- `dist/install.sh` regenerated from renamed sources (2326 lines), consistent with sources.

## Task Commits

1. **Task 1: Rename across code + tests** — `e067f0d` (refactor)
2. **Task 2: Rebuild dist + CHANGELOG** — `2356160` (chore)

## Files Created/Modified

- 26 renamed sources: `lib/*.sh` (+ `lib/engines/claude-code.sh`, `lib/README.md`, `lib/engines/README.md`), `install.sh`, `uninstall.sh`, `update.sh`, `doctor.sh`, `build.sh`, `src/package.json`, `tests/bash/{manifest,memory,multi-instance,personal-cmd}.bats`
- `dist/install.sh` — regenerated (generated artifact)
- `CHANGELOG.md` — `[Unreleased] ### Changed` entry

## Decisions Made

- **MANIFEST_VERSION 1 → 2:** the manifest filename and version key are part of the on-disk schema; per STRUCTURE.md, schema changes bump the version. Phase 2 migration keys off this.
- **Verification split (operator-approved):** local = `bash -n` (all `.sh` pass) + `bash build.sh` (green). The bats suite + `shellcheck` run as a Station11 round-trip before Phase 1 is marked done — `bats`/`shellcheck`/`jq` are absent on the Windows dev host.

## Deviations from Plan

None — plan executed as written. (`lib/prompts.sh` was listed in scope but contained no token; no-op.)

## Issues Encountered

- **Pending Station11 verification:** the bats test suite and `shellcheck` lint could not run locally (tooling absent on Windows). Local syntax + build are green; the full suite is a tracked pre-Phase-done round-trip, not a failure.

## Next Step

Ready for 01-02-PLAN.md (GitHub repo rename + public URLs + version + blocklist).

**Note for Phase 2 (migration):** existing installs carry the OLD shapes this rename changed — `~/.claudify-<name>/`, `claudify-<name>.service`, `claudify.json` (+ `.claudify_version` key), `# Claudify PATH —` marker, and `<!-- claudify:persona:* -->` markers. Phase 2 migration must rewrite all of these.
