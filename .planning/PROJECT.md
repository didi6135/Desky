# Desky

## What This Is

Desky lets one operator deploy a personal AI agent on their own Linux server in
under 10 minutes — isolated from the host so it can be trusted with sensitive
data, with persistent memory, self-scheduled routines, and backup/restore. The
core is **engine-agnostic** (Claude Code today; Gemini, Codex, or a local model
pluggable behind a fixed adapter contract). It targets solo freelancers and
small businesses, with a Hebrew-first path planned for later milestones.

Desky is the next chapter of the existing **Claudify** codebase — most of the
substrate already ships (see Validated). Phase 1 turns that substrate into a
"Good & Secure Base."

## Core Value

> A Desky operator can deploy a personal AI agent on their own Linux server in
> under 10 minutes, trust it with sensitive data because the agent is isolated
> from the host, and rely on it to remember, schedule its own work, and survive
> failure.

If isolation and durability fail, nothing else matters — that sentence is the bar.

## Requirements

### Validated

<!-- Shipped in the Claudify base and relied upon. Inferred from the codebase map + audit. -->

- ✓ One-command install (`curl … | bash`) — existing (`install.sh` / `dist/install.sh`)
- ✓ Multi-instance layout (`~/.claudify-<name>/`) — existing (`lib/layout.sh`)
- ✓ Per-instance systemd user unit + Tier-1 hardening — existing (`lib/service.sh`)
- ✓ Engine abstraction (10-function adapter contract) — existing (`lib/engines/`)
- ✓ Manifest registry + per-instance state, atomic writes — existing (`lib/manifest.sh`)
- ✓ Per-skill data directories (`$CLAUDIFY_SKILL_DATA`) — existing (`lib/memory.sh`)
- ✓ Personal command wrapper (`<name> doctor`, …) — existing (`lib/personal-cmd.sh`)
- ✓ Telegram delivery channel — existing (`telegram@claude-plugins-official`)
- ✓ Health-check `doctor` diagnostic — existing (`doctor.sh`)
- ✓ Resumable install (`.install-partial`) — existing (`lib/onboarding.sh`)

### Active

<!-- Phase 1 — "Good & Secure Base." Hypotheses until shipped and validated. -->

- [ ] **Rebrand** Claudify → Desky: paths (`~/.desky-<name>/`), service unit, registry, install URLs, banners, validators
- [ ] **Self-migrating** legacy installs: pre-3.4.5 single-instance *and* Claudify→Desky, idempotent, backup-first
- [ ] **Docs reflect reality**: README + architecture describe multi-instance, container-isolated, Desky-branded state (zero stale `claudify`/`claude-telegram` refs)
- [ ] **Container isolation**: agent runs in a rootless container; only `~/.desky-<name>/` visible inside; outbound-only network; seccomp profile — *headline security win, highest risk*
- [ ] **Backup + restore**: single encrypted tarball → restore to a different host → service active
- [ ] **Persistent memory (MCP)**: `remember` / `recall` / `forget` across conversations; per-instance SQLite + FTS5; operator-inspectable via `sqlite3`
- [ ] **Scheduled routines**: first-class recurring tasks ("every Monday 8am, …"), persist across reboot, run inside the agent's container
- [ ] **Hebrew persona by default**: detect `he_*` locale at install → seed Hebrew persona + localized wrapper help (persona layer only)
- [ ] **Phase 1 signoff**: full self-test (install → backup → restore on a 2nd host → routine runs unattended → Hebrew chat) → tag `v1.0.0`

### Out of Scope

<!-- Explicit boundaries with reasoning, so they don't creep back in. -->

- CRM / invoicing / calendar / hours / leads — Phase 2 (business fit)
- WhatsApp / Discord / Slack channels — Phase 2 (Telegram is the only channel in Phase 1)
- Hebrew invoice formats, Israeli calendar (חגים), RTL skill output, ת.ז./מע"מ/₪ — Phase 3 (Israeli verticals)
- Multi-user / team permissions — Phase 2; single-user trust model is the current security boundary
- Skill marketplace / discovery / install-from-name — Phase 4
- Billing / reseller model — Phase 5 (only when there's traction)
- Vector DB / embeddings for memory — Phase 2; Phase 1 ships free-form text + FTS5
- Cross-instance memory share — possibly never; violates single-user isolation
- iOS/Android client, self-hosted web UI — far future; chat channels are the interface

## Context

- **Brownfield.** Inherits the Claudify codebase: engine-agnostic Bash installer + focused `lib/*.sh` modules + a single Claude Code engine adapter, distributed as one built `dist/install.sh`. Codebase map lives in `.planning/codebase/`.
- **Reference mining.** Ideas sourced from three sibling agents in the parent folder — steal the *pattern*, skip the *runtime*:
  - **nanoclaw** → container-per-agent (Dockerfile, seccomp, entrypoint, volume strategy)
  - **openclaw** → backup/restore CLI + docs structure (`docs/install/`, `docs/start/`)
  - **hermes-agent** → routines (spec + cron-style scheduler + state persistence); skip its Python entirely
- **Known risk carried in.** Mount-namespace isolation already failed against AppArmor on Ubuntu 24.04 (old 3.4.5). Container isolation is therefore the highest-risk Phase 1 item — spike early on Station11 before sinking hours.
- **Verify loop.** Every install-path change round-trips on **Station11** (`~/test/autoinstall.sh`, multi-instance aware).
- **Tracking.** `bd` (beads) for issues; `bd remember` for cross-session knowledge. No `MEMORY.md`, no TodoWrite.
- **Doc discrepancy to reconcile during rebrand:** the codebase audit cites a "34-check" doctor while the contract checklist cites "28/28" — Phase 1 signoff should pin the real number.

## Constraints

- **Tech stack**: Bash for install/lifecycle (≤300 lines/file, ≤50/function); TypeScript on Bun for tooling + tests (no plain JS, no `any`, named exports). — CLAUDE.md code-quality rules.
- **Architecture invariants** (ADR-gated, not PR-gated): engine-agnostic core (no Claude-coupled refs outside `lib/engines/`), clean uninstall (system as if Desky never ran), substrate independence (plain files + SQLite, operator can `cat`/`sqlite3`/`vi` even with every process dead), single-user trust model (no per-skill sandboxing for adversaries).
- **Platform**: Linux only (Ubuntu 24.04 baseline); user-mode systemd + linger; outbound TCP only; all state under `~/.desky-<name>/`.
- **New dependency**: container isolation adds Podman/Docker — preflight must auto-install if missing.
- **Idempotency**: every script (install/update/doctor/backup/restore/uninstall) is safe to re-run.
- **No silent failures**: every `|| true` carries a justifying comment; otherwise explicit `fail "<reason> — try X"`.
- **Process / Git**: one task at a time (no parallelization unless asked); propose before destructive ops (`rm -rf`, force-push, anything touching Station11); verify locally before pushing; never push to `main` without approval (personal repo → direct commits after verify are fine).
- **Security**: secrets `600`, configs `644`, skill data `700`; scrub secrets from any shown output; no checksum/signature on the curl-piped installer (accepted under single-user trust).

## Key Decisions

<!-- Forks flagged "Pending" are deferred to the relevant phase's planning step, per owner. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Build the full Phase 1 (container + backup + memory + routines + Hebrew) before tagging v1.0 | Isolation/durability is the product differentiator — don't ship the "secure base" without the secure part | — Pending |
| Rebrand Claudify → Desky **before** container work | Renaming mid-container is painful; clean base first unblocks every other sub-phase | — Pending |
| Rename the existing GitHub repo (not a fresh one) | Preserves stars, issues, history | — Pending |
| Memory = free-form text + SQLite **FTS5** (no embeddings in P1) | Matches Anthropic's `memory_20250818` convention; embeddings are premature | — Pending |
| Routines are **per-instance** | Matches the substrate's isolation model | — Pending |
| Container runtime: leaning **Podman rootless (Quadlet)** — final call in a 1.3 spike | No daemon, true rootless, first-class systemd; prior AppArmor failure warrants a timeboxed spike first | — Pending |
| Backup encryption: leaning **age** over gpg/openssl — final call in 1.4 | Clean scripting + cheap single-binary dep; gpg symmetric UX is painful | — Pending |
| Architectural invariants (engine-agnostic / clean-uninstall / substrate-independence / single-user trust) | Inherited contract; breaking one needs an ADR + approval | ✓ Good (established) |

---
*Last updated: 2026-05-27 after initialization*
