# Project Issues Log

Enhancements discovered during execution. Not critical - address in future phases.

## Open Enhancements

### ISS-001: Stale mount-namespace isolation claims in lib/ header comments

- **Discovered:** Phase 1 Task 01-03-1 (2026-05-27)
- **Type:** Documentation
- **Description:** The header comments in `lib/layout.sh` (lines 7-11) and
  `lib/service.sh` (lines 4-6) claim each instance "runs in a private mount
  namespace where only its own `~/.desky-<name>/` folder is visible" and
  "cross-instance reads are kernel-blocked." The actual systemd unit body in
  `service.sh` (lines 67-88) explicitly EXCLUDES the mount-namespace directives
  (`PrivateTmp`, etc.) due to the AppArmor failure on Ubuntu 24.04, and the
  inline comment there correctly states the hardening "does NOT isolate this bot
  from other instances." The header comments contradict the code and overclaim
  isolation that isn't shipped. The README (01-03) was written to the honest
  reality; the code comments should be reconciled to match.
- **Impact:** Low (comments only; code behaves correctly and is honestly
  documented at the unit body)
- **Effort:** Quick
- **Suggested phase:** Phase 3 (Docs Sync — owns the zero-stale-refs sweep over
  `lib/` headers, CLAUDE.md, AGENTS.md), or Phase 4 (Container Isolation, when
  real isolation lands and the comments become true).

### ISS-002: Stale manifest.bats + memory.bats tests (old nested layout)

- **Discovered:** Phase 1 verification (2026-05-27, Station11 bats run)
- **Type:** Testing
- **Description:** 13 of 61 bats tests fail — `manifest.bats` (init_registry,
  register/unregister/preserve, init_instance, set_channel) and parts of
  `memory.bats` (manifest_set_skill, memory_assert_write/read). Root cause is NOT
  the rebrand: they set `DESKY_ROOT="$TEST_HOME/.desky"` and expect a nested
  `$DESKY_ROOT/instances.json` + `$DESKY_ROOT/desky.json`, plus
  `.service == "claude-telegram"` — all from the pre-ADR-0006 single-instance,
  nested layout. Current `manifest.sh` uses the flat `~/.desky-registry.json` +
  per-instance-dir layout, which `multi-instance.bats` (tests 39-42) covers
  correctly and which all pass. **Proven pre-existing:** running the suite at the
  pre-rename baseline commit `e921982` produces the identical 13 failures.
- **Impact:** Low (stale tests; the live code paths are correctly covered by
  multi-instance.bats and pass). Misleading red in CI until rewritten.
- **Effort:** Medium (rewrite both files to the flat layout + current service
  name + MANIFEST_VERSION=2)
- **Suggested phase:** Phase 2 (Migration touches manifest.sh — natural place to
  refresh its tests) or a dedicated test-hygiene pass.

## Closed Enhancements

[Moved here when addressed]
