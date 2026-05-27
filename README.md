# Desky

> **A self-hosted personal AI assistant for your own Linux server.**
> **Deploy once, reach it from Telegram — powered by your Claude Code subscription.**

Desky takes a fresh Linux server and turns it into a personal AI
assistant you talk to from Telegram. One curl command, one sudo prompt,
one browser login — that's the whole setup. Run a single instance for
yourself, or name several on the same box (one per client, project, or
team) — each is fully self-contained.

---

## Install

SSH into your server, then:

```bash
curl -fsSL https://raw.githubusercontent.com/didi6135/Desky/main/dist/install.sh | bash
```

The installer walks you through everything: creating a Telegram bot,
installing Claude Code, configuring the systemd service, completing
Claude OAuth. **First install takes about 3–5 minutes.**

By default the instance is named after your Linux user (so `whoami`
returning `david` gives you a `david` command and a `~/.desky-david/`
folder). To run more than one instance on the same host, name them:

```bash
curl -fsSL https://raw.githubusercontent.com/didi6135/Desky/main/dist/install.sh | bash -s -- --name client-a
```

**Safe to Ctrl-C anytime.** If you stop mid-install (network drop,
second thoughts, anything), just re-run the same command. Each input
you've already typed (bot token, Telegram user ID) is saved to
`~/.desky-<name>/.install-partial` (chmod 600) progressively as you go.
On re-run you get a quick prompt:

```
  Found saved progress from a previous install attempt:
    • Telegram bot token (saved)
  Continue from previous attempt? (No deletes the saved progress) [Y/n]
```

Press ENTER (or type `y`) to continue from where you stopped — the
installer skips the prompts you'd already answered and only asks about
inputs that are still missing. Type `n` and the saved progress is wiped
and you start fresh. The partial-state file is also removed
automatically on a successful finish.

### Preview without changing anything

```bash
curl -fsSL https://raw.githubusercontent.com/didi6135/Desky/main/dist/install.sh | bash -s -- --dry-run
```

Shows every action the installer would take, without doing any of them.

---

## Prerequisites

- **A Linux server with systemd.** Ubuntu 24.04 LTS is the tested
  baseline; Debian 12+, Fedora 39+ should also work.
- **`sudo` access** for one-time setup (enables `loginctl linger` so
  your bot survives logouts and reboots). The installer will offer to
  install Node.js and `jq` automatically if missing.
- **A Claude subscription** (Pro or Max) — the installer pauses once
  for you to complete OAuth.
- **A Telegram bot token** from [@BotFather](https://t.me/BotFather) —
  the installer walks you through creating one if you don't have it.
- **Your numeric Telegram user ID** from
  [@userinfobot](https://t.me/userinfobot) — same.

Full prerequisites: [docs/prerequisites.md](docs/prerequisites.md).

---

## After install

Each instance installs a **personal command** at `~/.local/bin/<name>`
— the short, ergonomic way to manage it. For an instance named `david`:

```bash
david status      # is the service running?
david logs        # follow the logs
david restart     # restart the service
david start       # start it
david stop        # stop it
david doctor      # run health checks
david update      # pull the latest Desky and refresh in place
david uninstall   # remove this instance entirely
david --help      # full subcommand list
```

(If `david: command not found` right after install, open a new terminal
or run `source ~/.bashrc` to pick up the new `~/.local/bin` PATH entry.)

Under the hood each instance is a user systemd service named
`desky-<name>.service`, so the raw commands work too as a fallback:

```bash
systemctl --user status  desky-david      # is it running?
journalctl --user -u     desky-david -f   # follow logs
systemctl --user restart desky-david      # restart
systemctl --user stop    desky-david      # stop
```

### Everything lives here

All of an instance's state is under a single hidden, self-contained
folder named after the instance:

```
~/.desky-<name>/
├── workspace/            the agent's working directory (persona at workspace/CLAUDE.md)
├── channels/telegram/    Telegram state (TELEGRAM_STATE_DIR)
│   ├── .env              bot token (chmod 600)
│   └── access.json       user allowlist
├── mcps/                 MCP servers
├── skills/               installed skills
├── hooks/                lifecycle hooks
├── data/                 persistent app data
├── claude/               engine config dir (CLAUDE_CONFIG_DIR — per-instance)
├── credentials.env       Claude OAuth token (chmod 600)
└── desky.json            this instance's manifest (versions, what's installed)

~/.desky-registry.json    side-car: every Desky instance on this host
```

Run several instances and each gets its own `~/.desky-<name>/` tree, its
own `desky-<name>.service`, and its own `<name>` command — no shared
state between them.

**A note on isolation.** The service runs with systemd Tier-1 hardening
(`NoNewPrivileges`, `RestrictNamespaces`, `RestrictSUIDSGID`,
`LockPersonality`, plus `MemoryMax` / `TasksMax` resource caps) that
protects the host from a misbehaving bot — fork-bombs, memory
exhaustion, privilege escalation. This is host protection, **not**
cross-instance filesystem isolation: instances on the same box share the
filesystem today. Container-based isolation is on the roadmap.

To remove a single instance:

```bash
david uninstall
# fallback: bash <(curl -fsSL https://raw.githubusercontent.com/didi6135/Desky/main/uninstall.sh) --name david
```

(Prompts for confirmation, leaves Claude Code itself + Bun + npm alone —
remove those manually if you want a completely clean system.)

## Diagnose (doctor)

When something looks off:

```bash
david doctor
# fallback: bash <(curl -fsSL https://raw.githubusercontent.com/didi6135/Desky/main/doctor.sh) --name david
```

It runs a battery of health checks (deps, layout, auth, systemd,
Telegram reachability) and gives a concrete next-step hint on every
failure.

---

## Update

Pulls the latest Desky from main and re-runs in place, preserving your
bot token, allowlist, and OAuth credentials. Typically ~10 seconds.

```bash
david update
# fallback: bash <(curl -fsSL https://raw.githubusercontent.com/didi6135/Desky/main/update.sh) --name david
```

What survives: `BOT_TOKEN`, the Telegram user-ID allowlist, your Claude
OAuth token, and your edits to `~/.desky-<name>/workspace/CLAUDE.md`.
What changes: the systemd unit, the Claude CLI / plugin (if newer is
out), the engine config seed (idempotent), and a service restart.

To overwrite tokens on purpose, re-install with `--reset-config`:

```bash
curl -fsSL https://raw.githubusercontent.com/didi6135/Desky/main/dist/install.sh | bash -s -- --name david --reset-config
```

---

## How it works

Architecture diagram, file layout, and the rationale behind each
component: [docs/architecture.md](docs/architecture.md).

When something breaks: [docs/troubleshooting.md](docs/troubleshooting.md).

Common questions: [docs/faq.md](docs/faq.md).

---

## Development

Source layout:

| Path | Purpose |
|---|---|
| `install.sh` | thin orchestrator (modular development form) |
| `lib/*.sh` | bash modules sourced by `install.sh` |
| `lib/engines/` | engine adapters (`claude-code.sh`, …) — see `docs/architecture.md §6` |
| `build.sh` | concatenates `lib/` + `install.sh` → `dist/install.sh` |
| `dist/install.sh` | the single-file installer that curl serves |
| `src/` | TypeScript modules (Bun) — `backup`/`restore` helpers |
| `tests/` | `tests/bash/` (bats) + `tests/ts/` (bun test) |
| `test.sh` | repo-root entry that runs both test suites |
| `docs/` | user-facing documentation |
| `.planning/` | project planning, roadmap, ADRs |

After editing `install.sh` or anything under `lib/`, run:

```bash
bash build.sh
```

…to regenerate `dist/install.sh` (the file curl users actually fetch).

To run the test suites:

```bash
bash test.sh                 # both suites; warn-skips a missing runner
bash test.sh --bash          # bash only (bats)
bash test.sh --ts            # TS only (bun test)
```

Conventions: [.planning/codebase/CONVENTIONS.md](.planning/codebase/CONVENTIONS.md).

---

## License

(TBD)
