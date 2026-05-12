# Roadmap

Five phases, executed in order. Each has its own doc under [phases/](phases/)
with concrete tasks and acceptance criteria.

A phase is finished when **every** acceptance criterion passes — no
"90% done, moving on."

---

## Phase 1 — Bootstrap `install.sh` ✅ DONE (2026-04-21)
**Goal:** a single curl-pipe-bash command takes a fresh Ubuntu/Debian
server to a running Claude+Telegram assistant in under 3 minutes.

**Shipped:** `install.sh` (modular under `lib/` + `build.sh` → `dist/install.sh`),
`doctor.sh` (28-check health report), `.claudify/` single-folder layout,
5 ADRs, verified end-to-end on Station11.

→ [phase-1-bootstrap.md](phases/phase-1-bootstrap.md)

---

## Phase 2 — Distribution ✅ DONE (alongside Phase 1)
**Shipped:** Repo is public at [github.com/didi6135/Claudify](https://github.com/didi6135/Claudify).
`dist/install.sh` tracked in git. Install one-liner works:
`curl -fsSL https://raw.githubusercontent.com/didi6135/Claudify/main/dist/install.sh | bash`.

**Deferred to a future sub-phase** (not blocking Phase 3+): versioned
git tags / GitHub releases, custom domain (`claudify.sh`). These are
nice-to-haves; the curl one-liner already works without them.

### (Original plan, for reference)

- Repo flips from private to public
- Stable install URL — either `raw.githubusercontent.com/didi6135/Claudify/main/install.sh` or a custom domain like `claudify.sh`
- Versioned releases (git tags + GitHub releases)
- `install.sh` accepts `CLAUDIFY_VERSION=v1.0.0` to pin
- README first instruction is the curl command, full stop

→ phases/phase-2-distribution.md *(to be written)*

---

## Phase 3 — Lifecycle  🚧 in progress
**Goal:** running an assistant for months, with multi-instance support
and clean operational tooling.

- ✅ `uninstall.sh` — one-command clean removal (2026-04-23)
- ✅ `update.sh` + `install.sh --preserve-state` — in-place refresh, preserves tokens, ~10s (2026-04-24)
- ✅ Starter `CLAUDE.md` persona seeded in workspace, edits survive updates (2026-04-24)
- ✅ `docs/architecture.md` — canonical structural reference (2026-04-26)
- 🚧 **3.4** Architectural refactor — multi-instance layout, engine abstraction, manifest files, personal commands, skill data substrate. **8 of 13 sub-tasks done** (most recently 3.4.5.1 + 3.4.5.2 on 2026-05-12). Remaining: 3.4.6 / 3.4.7 / 3.4.8 / 3.4.9
- ⏳ **3.5** `backup.sh` + `restore.sh` (TypeScript via Bun, first src/ usage)
- ⏳ **3.7** Keep README + ROADMAP synced as tasks land

→ [phase-3-lifecycle.md](phases/phase-3-lifecycle.md)
→ [phase-3-tasks/README.md](phases/phase-3-tasks/README.md) — task-by-task status board
→ [docs/architecture.md](../docs/architecture.md)

---

## Phase 4 — Security hardening 🚧 planned (was 3.6 in old numbering)
**Goal:** take the bot from `systemd-analyze` score ~9.6 ("UNSAFE")
to ≤2.5 ("OK"), via tiered systemd directives + a code-level audit.

Promoted from a Phase 3 sub-task to its own phase on 2026-05-12 so
it's first-class trackable.

- ⏳ **4.1** Tier-1 hardening (always-safe)
- ⏳ **4.2** Filesystem write-restriction (reduced — mount-NS superseded by 3.4.9 containers)
- ⏳ **4.3** Address families + syscall filter (Tier-3)
- ⏳ **4.4** Tighten file permissions
- ⏳ **4.5** doctor.sh security section
- ⏳ **4.6** Security documentation (README section + architecture.md status flip)

→ [phase-4-sec/README.md](phases/phase-4-sec/README.md)
→ [research/security.md](research/security.md) — threat model + audit

---

## Phase 5 — Memory + MCP ⏳ planned (was 4.0a-4.4 memory-track in old numbering)
**Goal:** the bot has memory — persona facts the operator controls,
conversation history searchable via FTS5, a 9-tool MCP server that
every skill talks to.

- ⏳ **5.0a** `claudify-memory` MCP server (9 tools, TypeScript/Bun)
- ⏳ **5.0b** Engine wires the MCP via real `engine_memory_setup`
- ⏳ **5.1** persona.db + lib/persona.sh + auto-render
- ⏳ **5.1.1** `<instance> remember <fact>` operator command
- ⏳ **5.2** Conversation log + FTS5 + `<private>` filter

→ [phase-5-mem-mcp/README.md](phases/phase-5-mem-mcp/README.md)
→ [research/memory.md](research/memory.md) — the source of truth for memory architecture

---

## Phase 6 — Skills & user management ⏳ planned (was 4.2/4.3/4.5/4.6 in old numbering)
**Goal:** skills are installable, the first real one (`reminders`)
ships, and onboarding a new Telegram user is a 30-second flow.

- ⏳ **6.1** DM pairing flow (replaces hand-edit of access.json)
- ⏳ **6.2** First real skill: `reminders` (canonical reference)
- ⏳ **6.3** Skill marketplace discovery + install UX
- ⏳ **6.4** `<instance> skill new` template generator

→ [phase-6-skills/README.md](phases/phase-6-skills/README.md)
→ [docs/skills.md](../docs/skills.md) — skill author contract

---

## Phase 7 — Observability & advanced security ⏳ planned (was Phase 5 in old numbering)
**Goal:** safe to leave running unattended for years. Originally was
Phase 5 (security & observability); renumbered on 2026-05-12 to make
room for the security hardening + memory + skills phases that came
earlier.

- Secret manager upgrade (move off plain `.env` to age/sops)
- Cost ceiling — hard cutoff at $X/day
- Audit log — every command the assistant ran
- Health check — external ping verifies alive-and-responsive
- Permission policy — what the assistant is / isn't allowed to do
- **codaki.com** SaaS-ish hosting (unblocked by 3.4.9 container delivery)
- (Conditional) Vector / semantic memory upgrade if FTS5 hits limits in real use
- (Conditional) Gmail / Calendar / Drive MCPs if they earn their keep

→ phases/phase-7-observability.md *(to be written)*

---

## Out of roadmap (intentionally)

These are things we **could** build but won't — they conflict with the
project's vision (see [PROJECT.md](PROJECT.md) non-goals):

- Operator-side CLI for managing many servers from one laptop
- A hosted SaaS version of Claudify
- Web/mobile UI alternatives to Telegram
- Multi-tenant deployments (multiple users sharing one assistant)

If a real need emerges, revisit by writing an ADR proposing the change.

---

## Progress tracking

Current phase: **Phase 3** — Lifecycle. 8 of 13 sub-tasks done as of
2026-05-12. Phases 1 & 2 done as of 2026-04-21.

Phase pipeline (post-reorg of 2026-05-12):
**Phase 3 (lifecycle)** → **Phase 4 (security)** → **Phase 5 (memory MCP)**
→ **Phase 6 (skills)** → **Phase 7 (observability)**.
