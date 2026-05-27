# ADR 0006: Multi-client isolation — flat layout (kept) + mount namespace (failed, replaced by containers)

**Status:** Partially accepted, partially superseded — see appendix 2026-05-10
**Date:** 2026-05-07 (original); appendix 2026-05-10
**Supersedes:** Aspects of `docs/architecture.md §3b` (the nested
`~/.claudify/instances/<name>/` layout) and 3.6.2's original
`ProtectHome=read-only + ReadWritePaths` plan.
**Partially superseded by:** [3.4.9 Containerize Claudify](../phases/phase-3-tasks/3.4.9-containerize.md) (containers replace mount-namespace approach for actual isolation).

## Context

Claudify supports multiple instances per host (Phase 3.4.5). Two
related questions surfaced during the security audit + multi-client
discussion:

1. **Path layout — flat (`~/.claudify-<name>/`) or nested
   (`~/.claudify/instances/<name>/`)?** Both work technically.
   Architectural plans through Phase 3.4.4 assumed nested.

2. **What actually isolates Client A's bot from Client B's data on
   the same host?** The original 3.6.2 plan was `ProtectHome=read-only`
   plus `ReadWritePaths=~/.claudify`. That restricts WRITES only —
   READS of other instances' data are still permitted because all
   instances run as the same Linux user and the bot's process IS
   the file owner. A prompt-injected Client A bot could
   `cat ~/.claudify/instances/client-b/credentials.env` and
   exfiltrate. The threat is real, the planned defense is
   insufficient.

A multi-client deployment (operator hosting Claudify for 3-5 paying
clients on one VPS) is an explicit use case the project owner
called out. Without strong isolation, this deployment shape is
unsafe.

## Decision

Two coupled decisions, recorded together because they reinforce
each other.

### Decision 1 — Flat top-level layout

Each instance lives at `~/.claudify-<name>/`. The default install
without `--name` uses `~/.claudify-default/`. There is no
`~/.claudify/` nesting layer; the registry moves to a side-car file
at `~/.claudify-registry.json`.

**Why flat over nested:**

- Psychological isolation maps directly to filesystem isolation.
  `cd ~/.claudify-client-a` and the operator is unambiguously in
  Client A's world. With nested, all clients live as siblings
  under one root; mental separation has to be enforced by
  discipline, not structure.
- Mount-namespace isolation (Decision 2) is more obvious and
  declarative with flat paths: `BindPaths=%h/.claudify-<name>` is
  exactly one folder. With nested, `BindPaths=%h/.claudify/instances/<name>`
  is awkward and exposes the whole `instances/` parent if
  misconfigured.
- The single-bot operator's mental model is unchanged. Today's
  installs land at `~/.claudify/`; post-3.4.7 migration lands them
  at `~/.claudify-default/`. The suffix is a one-time adjustment.
- Architecture.md's earlier nested layout was speculative; no
  shipping code yet depends on the path SHAPE (3.4.4's manifest
  uses path-resolver helpers that can swap forms in one line).

### Decision 2 — Mount-namespace isolation via systemd

Each instance's systemd unit uses:

```ini
ProtectHome=tmpfs
BindPaths=%h/.claudify-<name>
BindReadOnlyPaths=%h/.npm-global %h/.bun
Environment=CLAUDE_CONFIG_DIR=%h/.claudify-<name>/claude
```

This creates a per-service mount namespace where:
- `$HOME` is an empty tmpfs by default
- Only the explicitly-bound paths are visible
- `~/.claudify-<other-name>/` is **not present** in the bot's
  filesystem view — not "exists but read-blocked," literally
  invisible
- Read-only binds for the shared binaries (`~/.npm-global`,
  `~/.bun`) keep them shared but prevent the bot from modifying
  them

Per-instance Claude state via `CLAUDE_CONFIG_DIR` (Anthropic's
documented mechanism) means even Claude Code's own settings,
plugins cache, and project-trust state don't leak between
instances.

**Why mount-namespace isolation over alternatives:**

- **Stronger than `ProtectHome=read-only + ReadWritePaths`.** The
  earlier plan only restricted writes. Reads are the bigger threat
  — leaked OAuth tokens enable account takeover; leaked persona
  data enables impersonation.
- **Lighter than per-Linux-user isolation.** Creating a Unix user
  per instance gives gold-standard isolation but requires sudo at
  every install (user creation), separate `loginctl enable-linger`
  per user, separate npm-global / bun setups, and prevents the
  operator from `cd`-ing freely across instances.
- **Lighter than containers (Docker / podman / nspawn).** Adds a
  runtime dependency, breaks the clean-uninstall invariant
  (`rm -rf ~/.claudify-*` is no longer enough), and the operational
  complexity is significant for a personal-PA project.
- **Built into systemd.** No new tools, no new dependencies. The
  same systemd that already manages our service.
- **Operator unaffected.** From outside the unit's namespace (e.g.
  a regular shell), the operator sees the full home directory
  including all client folders. The restriction is per-service,
  not per-user.

### Decision 3 — Explicit names, no auto-renaming

Each install requires an explicit `--name <NAME>`. First install
without the flag uses `--name default` (producing
`~/.claudify-default/`). Subsequent installs without `--name` are
rejected with a clear error listing existing names.

The earlier suggestion (auto-rename: `~/.claudify`,
`~/.claudify-2`, `~/.claudify-3`) is rejected because:
- Operators can't remember which auto-numbered suffix maps to
  which client
- The folder name is the primary identifier; making it implicit
  defeats the psychological-isolation argument

## Consequences

### Positive

- **Strong, kernel-enforced isolation between client instances.**
  A prompt-injected Client A bot cannot reach Client B's data.
- **Operator UX clarified.** Each client lives at a known, named
  path. `cd ~/.claudify-client-a` works always.
- **Backup/restore simpler per-client.** `tar
  ~/.claudify-client-a` is the full backup of one client. Already
  matches the natural mental model.
- **Multi-client deployment becomes a supported use case**, not an
  awkward workaround.

### Negative

- **3.4.7 migration grows.** Existing single-instance installs at
  `~/.claudify/` need to be renamed to `~/.claudify-default/`,
  Claude state moved to `~/.claudify-default/claude/`, and the
  systemd unit rewritten. Effort estimate for 3.4.7 goes from
  ~30 min to ~1 hr.
- **3.6.2 (filesystem write-restriction) directives change.** The
  effort is the same (~45 min); the directives differ. Specs
  are updated.
- **3.4.5 (multi-instance layout) effort grows from ~2.5 hr to
  ~3.5 hr** with the layout flip and namespace wiring added.
- **Architecture.md §3b and §5a need rewriting.** The path layout
  diagrams and the registry section change.
- **Slightly more complex systemd unit.** `BindPaths` directives
  are less familiar than `ReadWritePaths`. Documented in
  3.6.2 and the security research doc.

### Neutral

- **Phase 4 work unaffected.** The MCP server, persona DB,
  conversation log, skill data dirs all use `${CLAUDIFY_INSTANCE_DIR}`
  resolved by `lib/layout.sh`. The path SHAPE changes; the env
  var doesn't, so consuming code is unchanged.
- **Manifest schema unchanged.** Same JSON shape for
  `claudify.json` and the registry. Only the file paths shift.

## Rejected alternatives

### A. Keep nested + accept the read leak

Single-instance and dual-instance use cases would still work.
Rejected because the multi-client use case is explicit and the
read leak is a real exfiltration vector, not theoretical.

### B. Per-Linux-user isolation

Strongest isolation. Rejected because:
- Requires sudo per install (creating users)
- Per-user systemd setup (linger per user)
- Per-user npm-global / bun (massive duplication of binaries)
- Operator can't navigate freely across instances
- Operational complexity outweighs the marginal security gain
  over mount-namespace isolation

### C. Container isolation (Docker / podman)

Maximum isolation. Rejected because:
- Adds a runtime dependency (Docker daemon or podman binary)
- Breaks `rm -rf ~/.claudify-*` clean uninstall
- Out of vision for a "single-curl install on Linux" project
- Mount-namespace gets us 90% of the benefit without containers

### D. Run-as-different-uid via systemd's User= directive

Would require root + system service, breaking ADR 0002 (user
service with linger). Not pursued.

## Verification

After 3.4.5 and 3.6.2 land, the verification test is:

```bash
# Install two instances
default install --name client-a    # uses test bot/user
default install --name client-b    # different bot/user

# Get Client A's main PID
pid=$(systemctl --user show claudify-client-a -p MainPID --value)

# From outside the unit, enter its mount namespace and list $HOME
sudo nsenter -t $pid -m -- ls -la /home/$USER

# Expected output:
#   .claudify-client-a/   ← visible
#   .npm-global/          ← visible (read-only)
#   .bun/                 ← visible (read-only)
# NOT visible:
#   .claudify-client-b/
#   .ssh/
#   .bashrc
#   anything else
```

If the `nsenter` reveal shows `.claudify-client-b/`, the isolation
is broken and the install must refuse to start.

## References

- [Phase 3.4.5 — Multi-instance layout](../phases/phase-3-tasks/3.4.5-multi-instance.md) (the post-research delta section is the operational manifestation of this ADR)
- [Phase 3.6.2 — Filesystem write-restriction](../phases/phase-3-tasks/3.6.2-fs-write-restriction.md) (updated to use the BindPaths approach)
- [Phase 3.4.9 — Containerize Claudify](../phases/phase-3-tasks/3.4.9-containerize.md) (the replacement for mount-namespace isolation)
- [.planning/research/security.md](../research/security.md) (threat model + decision rationale)
- [systemd.exec(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html) — `BindPaths`, `ProtectHome`, `RestrictAddressFamilies` references
- Anthropic Claude Code IAM docs — `CLAUDE_CONFIG_DIR` env var

---

## Appendix — 2026-05-10 — Decision 2 failed in practice; replaced by containers

### What we found on Station11

Decision 2 of this ADR specified that each instance's systemd unit
would gain `ProtectHome=tmpfs + BindPaths + BindReadOnlyPaths` to
create a private mount namespace per service. We implemented this
in `lib/service.sh::write_service` and tested on Station11 (Ubuntu
24.04 LTS, systemd 255).

**Result: directives parse correctly but silently no-op.**

Verification:
- `systemctl --user show claudify-client-a -p ProtectHome -p BindPaths`
  reports both as set
- `/proc/<bot-pid>/ns/mnt` returns the same namespace ID as the
  operator's shell (`mnt:[4026531841]`)
- `ls /proc/<bot-pid>/root/home/david/` shows the full host home
  directory including `~/.ssh`, `~/.bashrc`, and other instances'
  folders
- No journalctl warnings or errors

### Root cause

Ubuntu 24.04 ships with `kernel.apparmor_restrict_unprivileged_userns = 1`
by default. This AppArmor restriction prevents unprivileged user
namespaces from performing mount operations — which is exactly what
`ProtectHome=tmpfs` and `BindPaths=` need to do.

systemd silently downgrades when it can't create the namespace:
the directives are kept in the unit text but no namespace is
attempted. There's no warning in the journal because, from
systemd's perspective, the directives were "applied" (i.e., parsed
+ marked).

### What we tried

Adding `PrivateUsers=yes` (which creates a user namespace) and
`PrivateMounts=yes` (which explicitly requests mount-namespace
creation) — same result. AppArmor still blocks the mount operations
inside the user namespace. `kernel.apparmor_restrict_unprivileged_userns=1`
is the kernel's last word.

The fix would require `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`
on every host running Claudify — a system-wide setting that
weakens AppArmor for everything else on that machine. Not a
trade-off we're willing to make.

### Decision 2 status: SUPERSEDED

The mount-namespace approach to multi-client isolation is **dropped**
from Claudify's bash install path. The replacement:

| Use case | Mechanism | Spec |
|---|---|---|
| Solo install, 1-3 bots, operator trusts their skills | Tier-1 systemd hardening (3.6.1) — no kernel writes, resource caps. NO cross-instance isolation. Documented as such. | [3.6.1](../phases/phase-3-tasks/3.6.1-tier1-hardening.md) |
| Multi-tenant hosted (codaki.com), or solo with strong isolation | Containers (Docker / Podman) — kernel-enforced via the container's own namespace + cgroups. Works on Ubuntu 24.04 because containers don't depend on AppArmor's userns restriction. | [3.4.9](../phases/phase-3-tasks/3.4.9-containerize.md) |

### Decision 1 (flat layout) status: STILL ACCEPTED

The flat layout `~/.claudify-<name>/` (vs the nested
`~/.claudify/instances/<name>/`) was the right call independently
of the isolation question. It gives:

- Clearer visual separation per instance for the operator
- Cleaner uninstall (`rm -rf ~/.claudify-<name>`)
- Cleaner mapping to a future container's volume (one container =
  one folder)

Decision 1 stands.

### Decision 3 (explicit names) status: STILL ACCEPTED

`--name <NAME>` is required (default: `default`); no auto-renaming.
Stands.

### What this means for the codebase

- `lib/service.sh::write_service` — strip `ProtectHome=`, `BindPaths=`, `BindReadOnlyPaths=` directives. (Phase 3.6.2 reduced scope.)
- `lib/service.sh::write_service` — add Tier-1 hardening directives (3.6.1).
- ADR 0007 (TBD): record the container model as the official path for multi-tenant isolation. Reference 3.4.9 spec.

### Lessons

1. **Read AppArmor sysctls before designing user-mode sandboxing.**
   Should have checked `kernel.apparmor_restrict_unprivileged_userns`
   on the target distro before committing to the architecture.
2. **systemd "directive accepted" ≠ "directive enforced".** Without
   a journal warning to flag silent fallbacks, you have to test the
   actual effect with `/proc/<pid>/ns/*` comparisons.
3. **Containers were always the cleaner answer for multi-tenant.**
   We tried to avoid the new dependency; the kernel pushed back.
