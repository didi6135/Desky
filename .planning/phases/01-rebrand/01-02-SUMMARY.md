---
phase: 01-rebrand
plan: 02
subsystem: infra
tags: [bash, rebrand, github, install-url, versioning, validation]

requires:
  - phase: 01-01
    provides: Desky-renamed substrate with didi6135/Claudify URL placeholders
provides:
  - didi6135/Desky GitHub repo as the canonical public identity
  - All install/raw/dist URLs pointing at didi6135/Desky
  - SCRIPT_VERSION 0.2.0-dev
  - validate_instance_name blocklist covering claude/claudify/desky
affects: [03-readme, migration]

tech-stack:
  added: []
  patterns:
    - "Brand blocklist guards both old and new names during migration window"

key-files:
  created: []
  modified:
    - install.sh
    - update.sh
    - uninstall.sh
    - doctor.sh
    - build.sh
    - lib/personal-cmd.sh
    - lib/validate.sh
    - dist/install.sh

key-decisions:
  - "Flipped didi6135/Claudify URLs in doctor.sh + uninstall.sh too (beyond plan's file list) to satisfy the zero-Claudify-URL gate"
  - "GitHub repo rename was already done pre-execution; checkpoint auto-satisfied"

issues-created: []

duration: ~8 min
completed: 2026-05-27
---

# Phase 1 Plan 02: Public Identity Summary

**Public identity is now Desky end to end: repo `didi6135/Desky`, every install/raw/dist URL repointed, `SCRIPT_VERSION` → 0.2.0-dev, instance-name blocklist hardened to reject claude/claudify/desky. Curl one-liner resolves 200.**

## Performance

- **Duration:** ~8 min
- **Completed:** 2026-05-27
- **Tasks:** 2/2 (+ 1 checkpoint auto-satisfied)
- **Files modified:** 8

## Accomplishments

- All `didi6135/Claudify` URLs → `didi6135/Desky` across `install.sh`, `update.sh`, `uninstall.sh`, `doctor.sh`, `build.sh`, and `DESKY_RAW_BASE` in `lib/personal-cmd.sh`. Code path now has **zero** `didi6135/Claudify`.
- `SCRIPT_VERSION` bumped `0.1.0-dev` → `0.2.0-dev` (dev minor; v1.0.0 reserved for Phase 9).
- `validate_instance_name` blocklist re-added `claudify` → now blocks `claude`, `claudify`, `desky` (functionally verified: all three rejected, a normal name allowed).
- `dist/install.sh` regenerated; live `raw.githubusercontent.com/didi6135/Desky/.../dist/install.sh` returns **200** (old Claudify URL still redirects).

## Task Commits

1. **Task 1: Repoint URLs, bump version, blocklist** — `db3edf9` (feat)
2. **Task 2: Rebuild dist + CHANGELOG** — `1e639fe` (chore)

## Files Created/Modified

- `install.sh`, `update.sh`, `uninstall.sh`, `doctor.sh`, `build.sh` — install/raw URLs → Desky; `install.sh` version bump
- `lib/personal-cmd.sh` — `DESKY_RAW_BASE` value → Desky
- `lib/validate.sh` — blocklist hardened
- `dist/install.sh` — regenerated (generated artifact)
- `CHANGELOG.md` — `[Unreleased] ### Changed` entry

## Decisions Made

- **Checkpoint auto-satisfied:** the GitHub repo rename (`checkpoint:human-action`) was already done before this execution — `origin` points at `didi6135/Desky` and `gh repo view didi6135/Desky` succeeds. No human action needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Plan gap] Flipped URLs in `doctor.sh` + `uninstall.sh` (beyond the plan's `files_modified`)**
- **Found during:** Task 1 (URL repoint)
- **Issue:** The plan's `files_modified` listed only `install.sh, update.sh, lib/personal-cmd.sh, build.sh, lib/validate.sh`, but `doctor.sh` and `uninstall.sh` also carried `didi6135/Claudify` URLs. The plan's own verify gate requires **zero** `didi6135/Claudify` in the code path.
- **Fix:** Included both files in the URL replace.
- **Verification:** `git grep didi6135/Claudify` over the code path returns nothing.
- **Committed in:** `db3edf9`

---

**Total deviations:** 1 auto-fixed (1 plan-gap). **Impact:** required to pass the plan's own verify gate; canonical URLs. No scope creep.

## Issues Encountered

- **Pending Station11 verification:** bats suite + `shellcheck` not runnable on the Windows dev host. Local `bash -n` (all pass) + `bash build.sh` (green) + live URL 200 are the local evidence. Full suite is the tracked pre-Phase-done round-trip.

## Next Phase Readiness

Code + public URLs all say Desky. **Phase 1 not yet complete** — 01-03 (README refresh, has a human-verify checkpoint) remains.

Next: Phase 2 (Migration) — build `lib/migrate.sh` to migrate existing installs (pre-3.4.5 `~/.claudify/` and 3.4.5+ `~/.claudify-*/`) to the Desky layout. Carry forward the 01-01 migration note (dir, service, manifest filename + `.claudify_version` key, PATH marker, persona markers all changed).
