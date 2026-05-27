# Desky — Phase 1 Project Plan

> **Phase 1: Good and Secure Base.**
> Build the foundation that *any* agent — solo freelancer, small business,
> or a future Hebrew-first business product — can safely stand on. No
> business features in Phase 1. Phase 2 fits the base to business
> verticals; Phase 3 layers Hebrew/Israeli verticals on top.

**Status:** drafted 2026-05-27. Pending owner approval to start.
**Owner:** David (didi6135).
**Inherited base:** Claudify (renamed → Desky). Most foundational
infrastructure already shipped — see Audit section.

---

## 1. The single-sentence goal

> A Desky operator can deploy a personal AI agent on their own Linux
> server in under 10 minutes, trust it with sensitive data because the
> agent is isolated from the host, and rely on it to remember,
> schedule its own work, and survive failure.

That's the bar. Everything in Phase 1 serves that sentence.

---

## 2. Exit criteria (when is Phase 1 "done"?)

Concrete, testable list. Phase 1 ships when *every* line below is ✓.

| # | Criterion | How to verify |
|---|---|---|
| 1 | Install completes in under 10 min on a fresh Ubuntu 24.04 box | Station11 round-trip |
| 2 | Agent runs inside a Docker/Podman container, not on the host | `ps` shows containerd parent; agent can't `cat /etc/shadow` |
| 3 | Agent state can be **backed up** to a single tarball and **restored** to a different host | `desky backup` → scp → `desky restore` → service active, doctor 34/34 |
| 4 | Agent **remembers** facts across conversations (not just one session) | Tell agent something on Monday, ask Friday — it knows |
| 5 | Operator can define a **recurring routine** that runs without prompting | "Every Monday at 8am, summarize last week's logs" — works for 4 weeks unattended |
| 6 | Operator's interactive command is in **Hebrew by default** for Hebrew operators | `LANG=he_IL.UTF-8 desky --help` → Hebrew. Persona seeded in Hebrew when locale matches |
| 7 | `desky doctor` reports **green** on a fresh install AND on a migrated pre-3.4.5 install | 34/34 or higher |
| 8 | README + architecture.md describe **the world as it is today**, not the world of Claudify v1 | Grep for "claudify" / "claude-telegram" returns zero stale refs |
| 9 | I (the operator) would **use this for my own paid client work** without losing sleep | Self-test: one full week running Desky on a real client task |

If criterion 9 fails, Phase 1 isn't done — no matter what the green checks say.

---

## 3. Audit — what exists today (inherited from Claudify)

Shipped in the Claudify Phase 3 work. Most of the substrate is here.

| Area | What's there | Source |
|---|---|---|
| One-command install (`curl … \| bash`) | ✅ | `install.sh` + `dist/install.sh` |
| Multi-instance layout (`~/.claudify-<name>/`) | ✅ | `lib/layout.sh` |
| Per-instance systemd user unit (`claudify-<name>.service`) | ✅ | `lib/service.sh` |
| Tier-1 systemd hardening (NoNewPrivileges, MemoryMax, etc.) | ✅ | `lib/service.sh` |
| Engine abstraction (10-function contract — Claude, Gemini, etc. pluggable) | ✅ | `lib/engines/` |
| Manifest files (registry + per-instance) | ✅ | `lib/manifest.sh` |
| Per-skill data directories (`${CLAUDIFY_SKILL_DATA}` env var) | ✅ | `lib/memory.sh` |
| Personal command wrapper (`<name> doctor`, etc.) | ✅ | `lib/personal-cmd.sh` |
| Bot delivery via Telegram (one channel today) | ✅ | telegram@claude-plugins-official |
| 34-check doctor diagnostic | ✅ | `doctor.sh` |
| Resumable install + atomic state writes | ✅ | `lib/onboarding.sh`, `lib/manifest.sh` |

**What still says "Claudify" but is conceptually Desky:** README, CHANGELOG header, `lib/` headers, install URLs (`raw.githubusercontent.com/didi6135/Claudify/...`), service unit name (`claudify-<name>.service`), instance directory (`~/.claudify-<name>/`), registry file. The rebrand is a Phase 1 task in its own right (see 1.0 below).

---

## 4. Gap analysis — what's missing for "good and secure"

| Gap | Severity | Best teacher | What we steal |
|---|---|---|---|
| **No real isolation** between agent and host (systemd hardening protects the *host* from a misbehaving bot, but the bot still has filesystem access to anything `david` can see) | 🔴 critical | **nanoclaw** | Docker/Podman per-agent container, the lean `container/` directory pattern, seccomp profile |
| **No backup/restore** — losing the disk loses every conversation, every routine, every credential | 🔴 critical | **openclaw** | Their backup/restore CLI pattern. State tarball + atomic restore |
| **No persistent agent memory** across conversations — every chat starts blank | 🟡 high | own Phase 5 plan + Anthropic memory-MCP convention | Memory MCP + per-skill SQLite already in place |
| **No scheduled routines** — agent can't say "every Monday at 8am, do X" without an external cron | 🟡 high | **hermes-agent** | Routines as first-class objects + cron-style scheduler (port pattern, not Python) |
| **No migration path** for pre-3.4.5 installs to multi-instance | 🟢 low | — | One-off bash script (3.4.7 in the old plan) |
| **README/architecture.md** lie about the current state (single-instance, `claude-telegram`, etc.) | 🟢 low | — | Internal doc sync (3.4.8 in the old plan) |
| **Hebrew at the persona layer** is achievable but not wired by default | 🟢 low | — | Detect `$LANG`, seed Hebrew persona when locale matches |
| **Branding**: half the code still says "Claudify" | 🟢 low | — | Find/replace + rename `~/.claudify-*` → `~/.desky-*` migration step |

---

## 5. Phase 1 sub-phases (ordered)

Each sub-phase ships its own commit(s) + Station11 round-trip test +
phase-doc summary. Dependencies form a DAG below.

### 1.0 — Rebrand: Claudify → Desky (~3-4 hr)

**Goal:** the codebase, paths, service names, and docs say "Desky"
consistently. After this, the old Claudify name only appears in
historical changelog entries.

**Deliverables:**
- `lib/layout.sh` paths: `~/.claudify-<name>/` → `~/.desky-<name>/`
- Service unit: `claudify-<name>.service` → `desky-<name>.service`
- Registry: `~/.claudify-registry.json` → `~/.desky-registry.json`
- All `SCRIPT_VERSION`, banner text, help strings
- Install URLs (`raw.githubusercontent.com/didi6135/Desky/main/...`)
- New GitHub repo or rename of existing
- A one-shot migration helper: detects `~/.claudify-*/` on host, offers
  to rename to `~/.desky-*/` and rewrite the systemd unit
- `validate_instance_name` blocklist: replace `claudify` with `desky`

**Risk:** people with active Claudify installs need a smooth path forward. Migration helper is mandatory.

**Steals from:** nothing — purely Desky work.

---

### 1.1 — Migration logic (existing 3.4.7, ~1 hr)

**Goal:** any old install (pre-3.4.5 single-instance, *or* a 3.4.5+
Claudify install if the rebrand happened) detects and migrates itself
on `desky update`.

**Deliverables:**
- `lib/migrate.sh` (or inline in `install.sh`): detect legacy paths,
  ask for consent, move state, rewrite unit
- Handles both: pre-3.4.5 `~/.claudify/` and 3.4.5+ `~/.claudify-*/`
- Idempotent — running twice is a no-op
- `doctor.sh` reports migration status

**Risk:** misdetection wipes the wrong dir. Test on 3 distinct legacy
shapes before shipping.

**Steals from:** nothing.

---

### 1.2 — Docs sync (existing 3.4.8, ~1 hr)

**Goal:** README + `docs/architecture.md` describe the multi-instance,
container-isolated, Desky-branded reality. No stale refs to
`claude-telegram` or `~/.claudify/`.

**Deliverables:**
- README rewrite (install one-liner, multi-instance examples, wrapper
  UX, Hebrew note, link to docs)
- `docs/architecture.md` updated for container model
- `docs/install-container.md` (new — comes after 1.3 lands)
- `docs/troubleshooting.md` refreshed

**Risk:** none significant. This is hygiene.

**Steals from:** **openclaw**'s docs are extensive and well-organized
— look at their structure (`docs/install/`, `docs/start/`, `docs/help/`).

---

### 1.3 — Container isolation (existing 3.4.9, ~7-10 hr)

**Goal:** the agent process runs inside a Docker container with
host-restricted access. Filesystem isolation real, not metaphorical.
This is the headline security win.

**Deliverables:**
- `lib/container.sh` (or rewrite of `lib/service.sh` for container mode)
- Per-instance container: `desky-<name>` (image: `desky/agent:<version>`)
- Volume mount: only `~/.desky-<name>/` is visible inside the container
- Network: bridge mode, outbound-only (no inbound)
- Seccomp profile: deny dangerous syscalls
- AppArmor or SELinux profile if available
- Container managed via `systemctl --user start desky-<name>.service`
  (systemd-managed Podman or Docker rootless)
- `desky doctor` adds container-specific checks (image present,
  container running, volume mount correct, seccomp active)
- Dockerfile in repo + image-build CI job

**Risk: highest in Phase 1.**
- Ubuntu 24.04 user-mode systemd + Docker rootless has quirks
- Container build adds a dependency (Docker or Podman) — preflight
  must auto-install if missing
- Migration from non-container install needs a one-time data move

**Steals from:** **nanoclaw — directly.** Their entire codebase is the
"container per agent" pitch. We study:
- `nanoclaw/container/` directory layout
- Their Dockerfile + entrypoint
- Their seccomp profile
- The exact systemd unit they generate
- Their volume-mount strategy

**Skip from nanoclaw:** their entire orchestration layer (they have
their own onboarding flow we don't need — our `install.sh` already
does that).

---

### 1.4 — Backup + restore (existing 3.5, ~4 hr)

**Goal:** `desky backup` writes a single tarball of all instance state.
`desky restore <tarball>` lands it on a new host and brings the service
up.

**Deliverables:**
- `backup.ts` + `restore.ts` (TypeScript per ADR 0005 — first TS piece)
- Backup includes: instance dir tree, manifest, container image
  reference (not the image itself), credentials.env (encrypted with a
  password the operator supplies)
- Restore: idempotent, verifies tarball integrity, asks for password,
  reconstructs the instance, registers in registry, starts service
- Default backup destination: `~/desky-backups/`. Operator-configurable.
- Optional: `--remote scp://host/path` for off-host backup

**Risk:**
- Credentials in the tarball — encryption is mandatory
- Restore on a different OS version might fail (container abstracts this)

**Steals from:** **openclaw** has a mature backup CLI. Study their
tarball structure + their restore validation. We may not need all the
features (cloud backends, scheduled backups) — those are Phase 2.

**Skip from openclaw:** scheduled backup orchestration (use 1.6
routines later), multi-host orchestration.

---

### 1.5 — Persistent agent memory (MCP) (~6 hr)

**Goal:** the agent remembers facts across conversations. "On Monday
you told me Acme's renewal is March 15" — Desky knows this on Friday.

**Deliverables:**
- `claudify-memory` MCP server (standalone process or in-process
  module per engine adapter)
- Per-instance SQLite database: `~/.desky-<name>/data/_memory/store.db`
- Three operations: `remember(fact)`, `recall(query)`, `forget(key)`
- The engine adapter calls `engine_memory_setup` (already in the
  10-function contract — body is empty today) to register the MCP
- Operator can inspect: `sqlite3 ~/.desky-<name>/data/_memory/store.db`
- A way for the agent to volunteer to remember (not just on operator
  command) — likely a hook in the persona prompt

**Risk:**
- Memory shape: free-form text? Embeddings? Structured key/value?
  Phase 1 ships **free-form text with FTS5 search** (sqlite built-in).
  Embeddings are Phase 2.
- The agent storing every fact it sees → noise. Add a recency policy.

**Steals from:**
- **own Phase 5 plan** (memory-MCP was already designed)
- **Anthropic's memory_20250818 tool convention** — match the surface
  so future model updates work

**Skip:** vector DB, embeddings, cross-instance memory share — all
Phase 2 or later.

---

### 1.6 — Scheduled routines (~5 hr)

**Goal:** "every Monday at 8am, summarize last week's logs" is a
first-class concept. Routines persist across reboots. They run inside
the agent's container, not on the host.

**Deliverables:**
- Routine spec: name, cron expression, prompt, optional skill list
- Stored at `~/.desky-<name>/data/_routines/routines.json`
- A small systemd timer per routine (or one timer that dispatches)
- Routine execution: invokes the engine in non-interactive mode with
  the routine's prompt, captures output to a log, optionally posts to
  Telegram
- `desky routine list / add / rm / run-now` subcommands on the wrapper
- A routine can call any installed skill

**Risk:**
- Cron expressions are hostile to humans — accept ISO 8601 ranges too
  ("every Monday 08:00")
- A routine that fails should retry sensibly + alert the operator

**Steals from:** **hermes-agent** — they have routines built in
(`hermes-already-has-routines.md` and their state machine pattern).
We port the *concept*, not the Python.

**Skip from hermes:** the entire Python runtime. Routines are
sufficiently simple to implement in bash + a tiny TS scheduler.

---

### 1.7 — Hebrew at the persona layer (~1 hr)

**Goal:** Hebrew-locale operators land in a Hebrew-speaking agent by
default. Tiny effort, large product signal.

**Deliverables:**
- Detect `$LANG` / `$LC_ALL` at install time
- If `he_IL.UTF-8` (or anything starting `he_`), seed
  `${CLAUDIFY_WORKSPACE}/CLAUDE.md` with a Hebrew persona
- The Hebrew persona instructs the agent to reply in Hebrew by default
  but switch on operator request
- Wrapper `<name> --help` localized via a small bash i18n helper
  (Hebrew + English only in Phase 1)
- `desky doctor` reports detected locale + active persona language

**Risk:** trivial. Phase 1's smallest task.

**Steals from:** nothing — Desky-specific.

**Phase 1 explicitly does NOT cover:**
- Hebrew invoice formats
- Israeli calendar awareness (חגים)
- WhatsApp channel
- RTL skill output formatting
- ת.ז. validators, ₪ formatting, מע"מ
All of those land in Phase 3 (Hebrew/Israeli verticals).

---

### 1.8 — Phase 1 signoff (~2 hr)

**Goal:** verify exit criteria 1-9 from Section 2. Tag a release.

**Deliverables:**
- One full self-test: install on a fresh VPS, backup, restore on a
  different VPS, define one routine, let it run for 24 hours, talk to
  the agent in Hebrew
- Tag `v1.0.0` (the first real Desky version)
- Phase 2 (business fit) kickoff doc

---

## 6. Phase 1 dependency DAG

```
1.0 Rebrand ─┬─► 1.1 Migration ─┬─► 1.2 Docs sync ──┬─► 1.8 Signoff
             │                  │                   │
             │                  └─► 1.3 Container ──┤
             │                              │       │
             │                              └─► 1.4 Backup ─┤
             │                                              │
             └─► 1.5 Memory ──────► 1.6 Routines ──────────┤
                                                           │
                       1.7 Hebrew (independent) ───────────┘
```

**Critical path:** 1.0 → 1.3 → 1.4 → 1.8. The headline work is
container isolation; everything else can parallelize after rebrand.

**Total Phase 1 estimate:** ~30-35 hours of focused work. ~3 weeks of
evenings, or ~1 week dedicated. Plan slips happen — budget +50%.

---

## 7. Non-goals for Phase 1 (deferred)

These are real needs, but they belong in Phase 2 or later. Listing
them explicitly so they don't sneak into Phase 1 scope-creep.

| Non-goal | Where it belongs |
|---|---|
| CRM, invoicing, calendar, hours tracking, leads | Phase 2 (business fit) |
| WhatsApp / Discord / Slack channels | Phase 2 |
| Hebrew invoice formats, Israeli calendar, RTL skill output | Phase 3 |
| Multi-user permissions (team workspace) | Phase 2 (the small-biz audience) |
| Skill marketplace / discovery / install-from-name | Phase 4 |
| Billing model for selling Desky to clients | Phase 5 (when there's traction) |
| Vector DB / embeddings for memory | Phase 2 |
| Cross-instance memory share | Possibly never — single-user isolation is the security model |
| iOS/Android client app | Far future — the chat channels are the interface |
| Self-hosted web UI | Far future |

---

## 8. Reference codebase mining — steal/skip table

| Codebase | What we **steal** | What we **skip** | Why |
|---|---|---|---|
| **nanoclaw** | Container-per-agent (Dockerfile, seccomp profile, entrypoint, volume strategy). Their CLI's "be small enough to read" philosophy. | Their orchestration layer (`nanoclaw.sh` onboarding, container build flow). Their package manager (pnpm). | We have `install.sh` already; we don't need Node tooling on the host. |
| **openclaw** | Backup/restore CLI patterns. Docs structure (`docs/install/`, `docs/start/`, etc.). Channel abstraction pattern (Phase 2 prep). | The full 20-channel implementation. The web gateway. App-level auth (we have OS-level container isolation instead). | Half a million LOC = liability for a one-person product. |
| **hermes-agent** | Routine pattern: routine spec + cron-style scheduler + state persistence. Kanban as a *skill* (Phase 2). | The Python runtime entirely. Their state machine library. | We'd be adding a whole language; bash+TS is enough. |
| **Desky (Claudify)** | Everything in the Audit section (multi-instance, engine abstraction, wrapper, manifest, etc.) | The single-channel Telegram-only assumption (we'll generalize in Phase 2). | This is the substrate; we don't re-decide it. |

---

## 9. Open questions (decide before starting)

These need owner answers before sub-phase work begins.

| # | Question | Default answer if no answer |
|---|---|---|
| Q1 | Container runtime: **Docker rootless** or **Podman**? | Podman (no daemon, true rootless, but less common on Ubuntu) |
| Q2 | New GitHub repo `didi6135/Desky` or rename `didi6135/Claudify`? | Rename — preserves stars, issues, history |
| Q3 | Memory shape in Phase 1: **free-form text + FTS** or **typed key/value**? | Free-form text + FTS (matches Claude's `memory_20250818` convention) |
| Q4 | Routines: **per-instance** (each Desky has its own) or **shared across instances**? | Per-instance — matches the rest of the substrate |
| Q5 | Rebrand timing: **before** Phase 1.3 (container) or **after**? | Before — every Phase 1.x is harder if we're renaming mid-way |
| Q6 | Backup encryption: **gpg with operator password**, **age**, or **just plain tarball** + warn? | gpg+password (universal, no extra deps on most systems) |

---

## 10. Risks + mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Container isolation breaks on Ubuntu 24.04 user-mode systemd (we already saw this with mount-namespaces in old 3.4.5) | high | high | Test on Station11 *early* in 1.3, before sinking 5+ hours. Have a fallback: ship without containerization if rootless Docker doesn't work and re-plan. |
| Migration corrupts data (1.1) | low | catastrophic | Backup-first pattern: 1.1 forces a `desky backup` before mutating anything |
| Memory MCP performance bad with many routines querying | medium | medium | SQLite FTS handles 10k+ entries easily; cap memory entries per instance at 100k in Phase 1, revisit in Phase 2 |
| Scope creep — business skills sneak into Phase 1 | high | high | Section 7 (non-goals) is the line. When tempted, add to Phase 2 doc instead. |
| Solo-vs-team architectural debt — building solo first means team work in Phase 2 will be expensive | medium | medium | Document the boundary now. Single-user permissions = always "owner can do anything"; structure the code so a future ACL layer can wrap, not replace. |
| Rebrand breaks existing installs in the wild | low (we have one user) | medium | 1.1 migration handles it. Communicate clearly. |

---

## 11. Phase 2 preview (so this plan has a horizon)

Not committed — sketch only.

**Phase 2 — Business Fit-out (~40-60 hr):**
- Channel abstraction + WhatsApp channel
- CRM skill (clients, deals, notes)
- Invoicing skill (drafts, send, track payments)
- Calendar skill (Google Calendar via Anthropic MCP)
- Hours tracking skill
- Multi-user permissions (the "small business" path)

**Phase 3 — Hebrew + Israeli verticals (~20-30 hr):**
- Hebrew-aware skill outputs (invoice PDF, dates, RTL)
- Israeli formats: ת.ז. validation, מע"מ, ₪
- Calendar awareness: חגים, שבת, ימי שישי קצרים
- WhatsApp as primary channel for Israeli operators

**Phase 4 — Skill marketplace + distribution.**

**Phase 5 — Monetization model + the "freelancer-resells-Desky-to-clients" wedge.**

---

## 12. How we'll work

- **Issue tracking:** `bd` (beads). One bd issue per sub-phase, broken
  into sub-tasks. `bd ready` is the source of truth.
- **Memories:** `bd remember` for cross-session knowledge. No `MEMORY.md`.
- **Per-phase doc:** when a sub-phase ships, add a summary file at
  `planning-me/phase-1/1.X-<name>-summary.md` (date + result +
  Station11 round-trip).
- **Commits:** one commit per logical change. English commit messages.
  Co-authored-by trailer.
- **Push policy:** verify locally → push to main directly (per CLAUDE.md
  for personal repos). Force-push only with explicit operator approval.
- **Station11:** every sub-phase that touches the install path round-trips
  on Station11 before merge. Use `~/test/autoinstall.sh` (already
  multi-instance aware + collision-checking).

---

## 13. Decision: ready to start?

If the owner approves this plan as-is, the next action is **1.0
Rebrand**. That unblocks every other sub-phase.

If the owner wants changes:
- Reordering sub-phases — pencil-edit Section 5 + the DAG in Section 6
- Adding a sub-phase — slot it into 5, update the DAG, recompute the
  total in Section 6
- Cutting a sub-phase — move it to Section 7 (non-goals) with a note
- Changing audience priority (e.g., team-first instead of solo-first)
  — likely shifts 1.5 (memory), 1.6 (routines), and adds a
  permission-system task that doesn't exist today

Either way: nothing in Phase 1 starts until this doc is signed off.
