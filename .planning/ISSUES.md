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

## Closed Enhancements

[Moved here when addressed]
