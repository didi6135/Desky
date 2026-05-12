# Phase 4 — Security hardening — Task index

Was Phase 3.6 in the old numbering — promoted to its own phase on
2026-05-12 so the security tasks are first-class trackable items.

The phase overview lives at [`4-overview.md`](4-overview.md). The
threat model + audit + directive rationale live in
[`.planning/research/security.md`](../../research/security.md).

**Rule:** before starting any task, read its file end-to-end. Each one
specifies *exactly* which files change, what each step is, and how to
verify done.

## Status board

| Task | Title | Status | Estimated | Depends on | Blocks |
|---|---|---|---|---|---|
| 4 | [Phase 4 overview (Arm A + Arm B)](4-overview.md) | ⏳ pending | umbrella | Phase 3 closure | Phase 5 |
| 4.1 | [Tier-1 hardening (always-safe)](4.1-tier1-hardening.md) | ⏳ pending | ~30 min | 3.5 | 4.2 |
| 4.2 | [~~Filesystem write-restriction~~ — superseded, reduced to 5-min cleanup](4.2-fs-write-restriction.md) | ⏳ pending (reduced) | ~5 min | 4.1 | 4.3 |
| 4.3 | [Address families + syscall filter (Tier-3)](4.3-syscall-and-network.md) | ⏳ pending | ~30 min | 4.2 | — |
| 4.4 | [Tighten file permissions](4.4-file-permissions.md) | ⏳ pending | ~15 min | 3.5 | — |
| 4.5 | [doctor.sh security section](4.5-doctor-security-section.md) | ⏳ pending | ~30 min | 4.1, 4.2, 4.4 | — |
| 4.6 | [Security documentation](4.6-security-docs.md) | ⏳ pending | ~15 min | 4.1, 4.2 | — |

**Total estimated effort:** ~2 hr 5 min (4.2 was originally 45 min but reduced to 5 min once mount-namespace isolation was deferred to 3.4.9 containerize — see [ADR 0006 appendix](../../decisions/0006-multi-client-isolation.md)).

## Why two arms?

Per `4-overview.md`:

- **Arm A** (sub-tasks 4.1–4.6) — systemd-level hardening directives.
  Takes the unit from `systemd-analyze --user security` ~9.6
  ("UNSAFE") down toward ~2.5 ("OK").
- **Arm B** — broader code-level audit checklist (9 sections inside
  `4-overview.md`). Verifies every claim in `docs/architecture.md §11`
  is true in code. Catches things systemd hardening can't: supply
  chain, HTTPS-only, secrets-in-logs.

Both arms ship as part of Phase 4. Arm B is interleaved with the
sub-tasks rather than a separate task.

## Ship order

Tier order is the suggested ship order:
1. **4.1 Tier-1** (zero risk; always-safe)
2. **4.2** (reduced — 5 min cleanup)
3. **4.3 Tier-3** (syscall filter; full Station11 round-trip)
4. **4.4 / 4.5 / 4.6** can land alongside or after

## Phase rename note

Old numbering: `phase-3-tasks/3.6.x`. New numbering: `phase-4-sec/4.x`.
Internal cross-references updated; the umbrella file was renamed
from `3.6-security.md` to `4-overview.md`. `git log --follow` from
the renamed files traces back to the originals.
