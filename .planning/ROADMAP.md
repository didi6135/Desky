# Roadmap: Desky

## Overview

Desky turns the inherited Claudify substrate into a "Good & Secure Base": a
personal AI agent an operator can deploy on their own Linux server in under 10
minutes, trust with sensitive data because it runs isolated from the host, and
rely on to remember, schedule its own work, and survive failure. The journey
starts by rebranding and making old installs self-migrate, then delivers the
headline security win (container isolation) and durability (backup/restore),
adds persistent memory and scheduled routines, seeds a Hebrew persona by
default, and ends with a full self-test that tags `v1.0.0`. Business features,
extra channels, and Israeli verticals are deliberately out of scope until later
milestones.

This roadmap is the GSD render of the owner-drafted `planning-me/PROJECT-PLAN.md`.
The doc's "Phase 1" is the **v1.0 milestone**; its sub-phases 1.0–1.8 map 1:1 to
the GSD Phases 1–9 below.

## Domain Expertise

None (no `~/.claude/skills/expertise/` skills available).

## Milestones

- 🚧 **v1.0 — Good & Secure Base** — Phases 1–9 (in progress)
- 📋 **v2.0 — Business Fit-out** — channels (WhatsApp), CRM/invoicing/calendar/hours, multi-user (planned)
- 📋 **v3.0 — Hebrew + Israeli verticals** — RTL output, ת.ז./מע"מ/₪, חגים-aware calendar (planned)
- 📋 **v4.0 — Skill marketplace + distribution** (planned)
- 📋 **v5.0 — Monetization / reseller wedge** (planned)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Rebrand** - Claudify → Desky across paths, service unit, registry, URLs, validators, plus a one-shot host migration helper
- [ ] **Phase 2: Migration** - Any legacy install (pre-3.4.5 single-instance or Claudify→Desky) detects and migrates itself on `desky update`, backup-first and idempotent
- [ ] **Phase 3: Docs Sync** - README + architecture + troubleshooting describe the multi-instance, container-isolated, Desky-branded reality (zero stale `claudify`/`claude-telegram` refs)
- [ ] **Phase 4: Container Isolation** - Agent runs in a rootless container; only `~/.desky-<name>/` visible inside; outbound-only network; seccomp profile (headline security win, highest risk)
- [ ] **Phase 5: Backup + Restore** - `desky backup` → single encrypted tarball → `desky restore` on a different host → service active
- [ ] **Phase 6: Persistent Memory (MCP)** - `remember`/`recall`/`forget` across conversations; per-instance SQLite + FTS5; operator-inspectable via `sqlite3`
- [ ] **Phase 7: Scheduled Routines** - First-class recurring tasks ("every Monday 8am, …"), persist across reboot, run inside the agent's container
- [ ] **Phase 8: Hebrew Persona** - Detect `he_*` locale at install → seed Hebrew persona + localized wrapper help (persona layer only)
- [ ] **Phase 9: Signoff** - Full self-test (install → backup → restore on 2nd host → routine runs unattended → Hebrew chat) → tag `v1.0.0`

## Phase Details

### Phase 1: Rebrand
**Goal**: The codebase, paths, service names, and docs say "Desky" consistently. Old "Claudify" name only survives in historical changelog entries.
**Depends on**: Nothing (first phase)
**Research**: Unlikely (internal find/replace + rename; no new tech)
**Plans**: TBD

Plans:
- [ ] 01-01: Layout/service/registry rename (`~/.claudify-<name>/` → `~/.desky-<name>/`, `claudify-<name>.service` → `desky-<name>.service`, registry file)
- [ ] 01-02: Strings, banners, `SCRIPT_VERSION`, install URLs, `validate_instance_name` blocklist; GitHub repo rename
- [ ] 01-03: One-shot host migration helper (detect `~/.claudify-*/`, offer rename + rewrite systemd unit)

### Phase 2: Migration
**Goal**: Any old install migrates itself to the Desky multi-instance layout on `desky update` — handling both pre-3.4.5 `~/.claudify/` and 3.4.5+ `~/.claudify-*/`.
**Depends on**: Phase 1
**Research**: Unlikely (internal bash, established patterns)
**Plans**: TBD

Plans:
- [ ] 02-01: `lib/migrate.sh` — detect legacy paths, consent prompt, backup-first, move state, rewrite unit; idempotent
- [ ] 02-02: `doctor.sh` migration-status check; round-trip across 3 distinct legacy shapes on Station11

### Phase 3: Docs Sync
**Goal**: README + `docs/architecture.md` + troubleshooting describe the world as it is today. `grep claudify`/`claude-telegram` returns zero stale refs.
**Depends on**: Phase 2 (and Phase 4 for the container install doc)
**Research**: Unlikely (doc hygiene; reference openclaw's `docs/` structure)
**Plans**: TBD

Plans:
- [ ] 03-01: README rewrite (install one-liner, multi-instance examples, wrapper UX, Hebrew note)
- [ ] 03-02: `docs/architecture.md` (container model) + `docs/install-container.md` (after Phase 4) + `docs/troubleshooting.md`

### Phase 4: Container Isolation
**Goal**: The agent process runs inside a rootless container with host-restricted access — filesystem isolation real, not metaphorical. The headline security win.
**Depends on**: Phase 1
**Research**: Likely (new dependency + architectural decision + carried-in risk)
**Research topics**: Podman-rootless+Quadlet vs Docker-rootless on Ubuntu 24.04 user-mode systemd; AppArmor interaction (prior 3.4.5 mount-namespace failure); seccomp profile; nanoclaw's `container/` layout, Dockerfile, entrypoint, volume-mount strategy. **Spike early on Station11 before sinking hours.**
**Plans**: TBD

Plans:
- [ ] 04-01: Runtime spike on Station11 (Podman rootless vs Docker rootless) — decide Q1, validate against AppArmor
- [ ] 04-02: `lib/container.sh` + per-instance container, single-volume mount (`~/.desky-<name>/`), outbound-only network, seccomp profile
- [ ] 04-03: systemd-managed container unit; preflight auto-installs runtime if missing; data move from non-container install
- [ ] 04-04: `desky doctor` container checks (image present, container running, mount correct, seccomp active); Dockerfile + image-build CI

### Phase 5: Backup + Restore
**Goal**: `desky backup` writes a single encrypted tarball of all instance state; `desky restore <tarball>` lands it on a new host and brings the service up.
**Depends on**: Phase 4
**Research**: Likely (encryption-tool decision + external pattern)
**Research topics**: `age` vs gpg for backup encryption (final call here — Q6); openclaw backup CLI tarball structure + restore-validation pattern.
**Plans**: TBD

Plans:
- [ ] 05-01: `backup.ts` — instance tree + manifest + container image reference + encrypted credentials; default dest `~/desky-backups/`
- [ ] 05-02: `restore.ts` — verify integrity, prompt password, reconstruct instance, register, start service; idempotent; optional `--remote scp://…`

### Phase 6: Persistent Memory (MCP)
**Goal**: The agent remembers facts across conversations via a memory MCP server backed by per-instance SQLite + FTS5; operator can `sqlite3` the store.
**Depends on**: Phase 1
**Research**: Likely (MCP shape + fast-moving Anthropic convention)
**Research topics**: memory-MCP server pattern (standalone vs in-process per adapter); Anthropic `memory_20250818` tool convention (match the surface); FTS5 schema + recency/cap policy (100k entries P1).
**Plans**: TBD

Plans:
- [ ] 06-01: Memory MCP server + per-instance store (`~/.desky-<name>/data/_memory/store.db`); `remember`/`recall`/`forget`
- [ ] 06-02: Wire via `engine_memory_setup` (10-fn contract); persona hook so the agent volunteers to remember; operator-inspectable

### Phase 7: Scheduled Routines
**Goal**: "Every Monday at 8am, summarize last week's logs" is a first-class, per-instance concept that persists across reboots and runs inside the agent's container.
**Depends on**: Phase 6
**Research**: Likely (scheduler architecture + external pattern)
**Research topics**: systemd timer-per-routine vs single dispatcher timer; cron-expression parsing (accept ISO 8601 ranges too); hermes-agent routine-spec + state-persistence pattern (port concept, skip Python); retry + operator alerting.
**Plans**: TBD

Plans:
- [ ] 07-01: Routine spec + store (`~/.desky-<name>/data/_routines/routines.json`); scheduler (systemd timer dispatch)
- [ ] 07-02: `desky routine list/add/rm/run-now`; non-interactive engine invocation, log capture, optional Telegram post; retry + alert

### Phase 8: Hebrew Persona
**Goal**: Hebrew-locale operators land in a Hebrew-speaking agent by default. Persona layer only — no business/RTL/Israeli formats (those are v3.0).
**Depends on**: Phase 1
**Research**: Unlikely (locale detect + small bash i18n; Desky-specific)
**Plans**: TBD

Plans:
- [ ] 08-01: Detect `$LANG`/`$LC_ALL` (`he_*`) at install → seed Hebrew persona in `${WORKSPACE}/CLAUDE.md`; wrapper `--help` i18n (he/en); `doctor` reports locale + persona language

### Phase 9: Signoff
**Goal**: Verify exit criteria 1–9 from PROJECT-PLAN §2, then tag the first real Desky release.
**Depends on**: Phases 3, 5, 7, 8
**Research**: Unlikely (verification + release)
**Plans**: TBD

Plans:
- [ ] 09-01: Full self-test — fresh-VPS install → backup → restore on a 2nd VPS → define a routine → 24h unattended run → Hebrew chat; reconcile the doctor check-count (28 vs 34)
- [ ] 09-02: Tag `v1.0.0`; write Phase 2 (Business Fit-out) kickoff doc

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

**Dependency DAG (from PROJECT-PLAN §6):**
```
1 Rebrand ─┬─► 2 Migration ─► 3 Docs sync ──────────┬─► 9 Signoff
           │                                        │
           ├─► 4 Container ─► 5 Backup ─────────────┤
           │                                        │
           ├─► 6 Memory ─► 7 Routines ──────────────┤
           │                                        │
           └─► 8 Hebrew (independent) ──────────────┘
```
Critical path: 1 → 4 → 5 → 9.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Rebrand | v1.0 | 0/3 | Not started | - |
| 2. Migration | v1.0 | 0/2 | Not started | - |
| 3. Docs Sync | v1.0 | 0/2 | Not started | - |
| 4. Container Isolation | v1.0 | 0/4 | Not started | - |
| 5. Backup + Restore | v1.0 | 0/2 | Not started | - |
| 6. Persistent Memory | v1.0 | 0/2 | Not started | - |
| 7. Scheduled Routines | v1.0 | 0/2 | Not started | - |
| 8. Hebrew Persona | v1.0 | 0/1 | Not started | - |
| 9. Signoff | v1.0 | 0/2 | Not started | - |
