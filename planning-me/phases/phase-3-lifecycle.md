# Phase 3 — Lifecycle

**Status:** in progress (started 2026-04-23)
**Goal:** Claudify is safe to run for months, not just install once. Clean
uninstall, in-place updates that preserve state, backup/restore for
server migrations.

Language choice for this phase: **bash for small things (uninstall),
TypeScript-via-Bun for anything bigger.** Per ADR 0005.

---

## End-state target

```bash
# Safe uninstall — leaves Claude Code itself, removes only Claudify
curl -fsSL .../uninstall.sh | bash

# Update without losing state (OAuth token + bot token + allowlist preserved)
curl -fsSL .../update.sh | bash

# Backup everything Claudify owns to a tarball
bash update.sh --backup    # (or separate backup.sh)

# Restore from a tarball onto a fresh server
bash restore.sh ./claudify-backup-2026-04-30.tar.gz
```

---

## Tasks

Ordered small → large. Don't start the next until the previous is
merged and tested on Station11.

> **Detailed per-task specs are in [`phase-3-tasks/`](phase-3-tasks/README.md).**
> Each numbered task below has its own file with goal, scope, exact
> files affected, ordered steps, acceptance criteria, and test plan.
> The index at [`phase-3-tasks/README.md`](phase-3-tasks/README.md) is
> the live status board.

### 3.1 — `uninstall.sh` (bash, ~30 min) ✅ DONE 2026-04-23

**Goal:** one command cleanly removes everything Claudify installed,
leaving the system exactly as it was before (minus whatever the
operator added outside Claudify's scope).

**Scope:**
- Stop + disable systemd service
- Remove `~/.config/systemd/user/claude-telegram.service`
- `rm -rf ~/.claudify/` (all per-bot state)
- `systemctl --user daemon-reload`
- Print a summary of what was removed

**Explicitly NOT removed** (the operator may have other uses):
- `~/.claude/` (Claude Code's user-wide state — plugins cache, settings)
- `~/.claude.json` (Claude Code's onboarding state)
- `~/.bun/` (Bun runtime — also useful for other things)
- `~/.npm-global/` (npm prefix — may have other globals)
- Linger for the user (rarely wants to flip back off)

Each exclusion gets a line in the summary output so the operator sees
what's left and can decide to remove it manually.

**Delivery:**
- `uninstall.sh` at repo root, committable
- Curl URL works: `bash <(curl -fsSL .../uninstall.sh)`
- Mentioned in README under "Uninstall"

### 3.2 — `update.sh` + `install.sh --preserve-state` flag (bash, ~1–2 hrs) ✅ DONE 2026-04-24

**Goal:** pull the latest `install.sh` from main and re-run in a mode
that keeps existing `credentials.env`, `telegram/.env`, and
`telegram/access.json`. Only the systemd unit, claude/plugin binaries,
and `~/.claude.json` seed get refreshed.

**Scope:**
- New flag on `install.sh`: `--preserve-state`
  - Behaves like normal install, but:
    - `credentials.env`, `telegram/.env`, `telegram/access.json` are
      preserved if present (no rewrite even if env vars differ)
    - `oauth_setup` skipped entirely if credentials.env exists
    - `write_service` still rewrites the unit (so unit changes land)
    - `seed_claude_state` still runs (harmless no-op when already seeded)
- `update.sh` at repo root: fetches latest `dist/install.sh`, invokes
  with `--preserve-state --non-interactive`
- Target: 10–20 seconds total on a healthy install

**Delivery:**
- Curl URL for `update.sh`
- Tested: deliberately modify a file, run update, confirm state preserved

### 3.3 — Seed starter `CLAUDE.md` persona (bash, ~30 min) ✅ DONE 2026-04-24

> *Note:* This is technically a Phase 5 (Memory) item, pulled
> forward because it's small and makes the bot feel personal. It's what
> turns generic Claude into *"my* Claude."

**Goal:** after install, `~/.claudify/workspace/CLAUDE.md` exists with
a starter persona the operator can edit. Claude reads it on every
session start (that's how Claude Code's `--add-dir` and CWD-based
CLAUDE.md discovery works).

**Scope:**
- New step in `install.sh` after `write_service`: writes
  `~/.claudify/workspace/CLAUDE.md` **only if it doesn't already exist**
  (idempotent; never clobbers operator edits)
- Default contents: minimal skeleton with TODO-style placeholders for
  name, language preference, timezone, response-style guidance
- Over time, the skeleton can absorb fields from `who-am-i.md`

**Delivery:**
- Tested: after install, bot replies in a style that matches the seed
- Operator can edit `~/.claudify/workspace/CLAUDE.md` and see behavior change on next message

### 3.4 — Architectural refactor: multi-instance + engine abstraction + reorg (TS+bash, ~6–8 hrs)

**Goal:** implement everything `docs/architecture.md` describes that's
not yet built. After this lands, every entrypoint speaks the new
model and the codebase is in long-term shape.

**Scope (each bullet is a separate commit):**

1. **Repo skeleton** — create `lib/engines/`, `src/`, `tests/bash/`,
   `tests/ts/`. Add minimal `tsconfig.json` + `package.json` under
   `src/` so `bun install && bun test` works (with one canary test).
   Delete unused `templates/{access.json,claude-telegram.service}`.
2. **`lib/steps.sh` split** — break ~430-line `steps.sh` into
   `onboarding.sh`, `configs.sh`, `service.sh`, `oauth.sh`,
   `manifest.sh`. Update `install.sh` source order + `build.sh`
   MODULES list. `bash -n` + smoke test on Station11.
2.1. **Resume interrupted install** — write inputs to
   `~/.claudify/.install-partial` (chmod 600) the moment they're
   collected, source on re-run if present. No flags, no prompts.
   Re-running picks up where Ctrl-C dropped. See
   [3.4.2.1](phase-3-tasks/3.4.2.1-resume-install.md).
3. **Engine abstraction** — extract Claude-specific code into
   `lib/engines/claude-code.sh` implementing the 6-function contract
   (`engine_install`, `engine_auth_check`, `engine_auth_setup`,
   `engine_run_args`, `engine_status`, `engine_uninstall`). Replace
   direct `claude` calls in step modules with `engine_*` calls.
4. **Manifest files** — `lib/manifest.sh` reads/writes
   `~/.claudify/instances.json` and per-instance `claudify.json`.
   `install.sh` writes both at the end. `doctor.sh` reads them.
5. **Multi-instance layout** — change paths from `~/.claudify/...` to
   `~/.claudify/instances/<name>/...`. Add `--name <NAME>` flag to
   every entrypoint, default `default`. Service unit name becomes
   `claudify-<name>.service`.
6. **Personal command wrapper** — `lib/personal-cmd.sh` generates
   `~/.local/bin/<name>` with the dispatch table (`doctor`,
   `update`, `uninstall`, `status`, `logs`, `restart`, `stop`,
   `start`). Adds `~/.local/bin` to PATH in `~/.bashrc` if needed.
   Validation per `lib/validate.sh`'s blocklist.
7. **Migration logic** — `install.sh` detects old single-instance
   layout (`~/.claudify/claudify.json` at root) and migrates to
   `instances/default/` + renames service. One-time, idempotent.
8. **Docs in sync** — README updated for `--name` and personal
   commands; doctor.sh + uninstall.sh + update.sh adopt new paths;
   CHANGELOG entry.

**Acceptance:**
- [ ] Fresh install on Station11 (autoinstall) creates
      `~/.claudify/instances/default/` and `~/.local/bin/default`
      (or whatever the operator picks)
- [ ] `default doctor` works
- [ ] Second install with `--name business` creates a parallel
      instance without touching the first
- [ ] Migration from old single-instance layout runs cleanly
      (test by installing the *previous* version on a fresh VPS,
      then updating to the new one)
- [ ] All bash files under 300 lines; no function over 50 lines
- [ ] `bash test.sh` runs both bash + TS canary tests, both pass

### 3.4.9 — Containerize Claudify (~7 hrs)

**Goal:** add a Docker / Podman delivery shape alongside the curl-bash
install. Same codebase, two delivery paths. Solo users keep their
familiar `curl … | bash`; codaki.com (and anyone hosting multi-tenant)
gets containers with kernel-enforced isolation.

**Why now:** the mount-namespace approach from
[ADR 0006](../decisions/0006-multi-client-isolation.md) was confirmed
broken on Ubuntu 24.04 (AppArmor blocks unprivileged userns
mount operations). Containers are the production answer for multi-
tenant. Building the image now means codaki.com (separate project)
can drop straight into the container shape when it kicks off.

**Scope:**
- `Dockerfile`, `lib/boot.sh` (container entrypoint), `compose.yaml`,
  `test-container.sh`, `.dockerignore`
- `lib/layout.sh` gains a `CLAUDIFY_CONTAINERIZED=1` mode (paths
  resolve to `/state`)
- `install.sh` skips systemd-related steps in container mode
- `docs/install-container.md` operator-facing docs
- README adds an "Install via Docker" section

**Acceptance:**
- [ ] `docker build` succeeds; image ≤ 500 MB
- [ ] `docker compose up` runs a working bot with real Telegram creds
- [ ] `bash test-container.sh` smoke-test green (no network, fake creds)
- [ ] State survives container restart; `down -v` resets it
- [ ] Solo install still works on Station11 (no regression)

See [phase-3-tasks/3.4.9-containerize.md](phase-3-tasks/3.4.9-containerize.md)
for full spec.

### 3.5 — `backup.sh` + `restore.sh` (TypeScript via Bun, ~3–4 hrs)

**Goal:** serialize one or more instances' state into a tarball that
can be dropped onto a fresh server to rehydrate the bot.

**Scope:**
- `src/backup.ts`: tar `~/.claudify/instances/<name>/` + the systemd
  unit file + the relevant `~/.claude.json` trust slice →
  `claudify-<name>-<host>-<timestamp>.tar.gz`. Flag: `--name <NAME>`
  (required) or `--all`. Optional `--out <dir>`.
- `src/restore.ts`: untar onto a fresh server, fix permissions,
  re-create systemd unit, `daemon-reload`, start, run doctor. Refuses
  to overwrite an existing instance of the same name.
- `backup.sh` + `restore.sh` at repo root are bash shims that find
  bun and exec into the TS entrypoints.

**Acceptance:**
- [ ] Round-trip tested: backup on Station11 → uninstall → restore →
      `default doctor` reports green
- [ ] `--all` mode creates one tarball per instance
- [ ] Refuses to restore on top of an existing instance with same name
- [ ] First piece of TypeScript code in production use; sets the
      pattern for future TS modules

### 3.6 — ~~Security hardening~~ MOVED to [Phase 4](phase-4-sec/) on 2026-05-12

The 6 sub-tasks live at [`phase-4-sec/`](phase-4-sec/README.md) with
their own status board. They were renumbered `3.6.x` → `4.x`. The
work itself is unchanged; security is now first-class trackable as
its own phase rather than a sub-task of Phase 3.

### 3.7 — Update README + ROADMAP + status docs

Keeps docs in sync rather than all at once at the end of the phase.
Lands at the end of each numbered task above.

---

## Acceptance criteria

Phase 3 is **done** when:
- [x] `uninstall.sh` removes Claudify state cleanly and reports what was kept
- [x] `update.sh` upgrades an install in <20s without re-OAuth
- [x] `CLAUDE.md` lives in `~/.claudify/workspace/`, persists across updates, demonstrably changes bot behavior
- [ ] Architecture refactor (3.4) lands — multi-instance layout, engine abstraction, personal commands, manifest, lib/steps.sh split, src/ + tests/ skeleton, migration from old layout
- [ ] `backup.sh` produces a tarball; `restore.sh` rehydrates it on a fresh server; doctor passes
- [ ] All entrypoints accept `--name`; personal command wrappers work
- [ ] All bash files ≤ 300 lines; functions ≤ 50 lines
- [ ] `bash test.sh` passes (bash bats + TS bun test)
- [ ] All entrypoints documented in README with curl one-liners
- [ ] `phase-3-lifecycle.md` updated with status markers as tasks close

---

## Out of scope for Phase 3

- Security hardening (moved to [Phase 4](phase-4-sec/))
- Memory MCP + persona + conversation log ([Phase 5](phase-5-mem-mcp/))
- DM pairing, reminders skill, skill marketplace ([Phase 6](phase-6-skills/))
- Cost ceiling, audit log, health check endpoint (Phase 7)
- Gmail / Calendar / Drive MCPs (Phase 7+)
- Discord / WhatsApp / email channels (Phase 7+)
- Multi-engine implementation (Phase 7+ — only triggered per ADR 0005 conditions)
- Hosted SaaS path (out of vision — see PROJECT.md non-goals)
