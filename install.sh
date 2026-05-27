#!/usr/bin/env bash
# desky install.sh — bootstrap Claude Code + Telegram on this Linux server
#
# Usage (target server, after SSH'ing in):
#   curl -fsSL https://raw.githubusercontent.com/didi6135/Desky/main/dist/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --name client-a       # named instance
#   curl -fsSL .../install.sh | bash -s -- --dry-run
#   BOT_TOKEN=… TG_USER_ID=… INSTANCE_NAME=… bash install.sh
#
# When distributed, the BUILT single-file output of build.sh
# (dist/install.sh) is what users actually fetch. This file (install.sh
# at the project root) is the modular development form that sources
# lib/*.sh below.
#
# Dependencies on this server:
#   - bash, coreutils, util-linux (provides /usr/bin/script), curl
#   - node >= 20 + npm
#   - sudo (used ONCE for `loginctl enable-linger`)
#
# See:
#   - .planning/phases/phase-1-bootstrap.md  build plan
#   - docs/architecture.md                   what this installs
#   - docs/troubleshooting.md                when something breaks

set -euo pipefail

SCRIPT_VERSION="0.2.0-dev"

# Resolve LIB_DIR even when invoked via symlink.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Order matters:
#   ui.sh         — opens the log file, defines colors and ok/warn/fail
#   layout.sh     — INSTANCE_NAME-aware paths (~/.desky-<name>/...)
#                   sourced BEFORE args.sh because args.sh::parse_args calls
#                   desky_init_layout to refresh paths after --name parsing
#   validate.sh   — pure validators (validate_instance_name lives here)
#   args.sh       — parse_args + run() (depends on fail, validate_instance_name,
#                                       desky_init_layout)
#   prompts.sh    — TTY detect + ask family (depends on fail)
#   preflight.sh  — uses ui + prompts
#   engine.sh     — picks the engine adapter and sources lib/engines/<id>.sh
#                   into scope (defines all engine_* contract functions)
#   manifest.sh   — registry + per-instance manifest read/write helpers (uses jq)
#   personal-cmd.sh — wrapper at ~/.local/bin/<name> + rc-file PATH update
#                   (needs no other lib; called after manifest writes)
#   memory.sh     — per-skill data dirs + ${DESKY_SKILL_DATA} resolver
#                   (uses manifest_get_skill_memory, so must follow manifest.sh)
#   onboarding.sh — intro, BotFather/userinfobot walkthroughs, collect_inputs
#   configs.sh    — bot .env + access.json + workspace persona (CLAUDE.md)
#   service.sh    — systemd unit write/start + final summary (uses engine_run_args)
#   oauth.sh      — interactive OAuth orchestration (uses engine_auth_check, engine_auth_setup)
# shellcheck source=lib/ui.sh
source "$LIB_DIR/ui.sh"
# shellcheck source=lib/layout.sh
source "$LIB_DIR/layout.sh"
# shellcheck source=lib/validate.sh
source "$LIB_DIR/validate.sh"
# shellcheck source=lib/args.sh
source "$LIB_DIR/args.sh"
# shellcheck source=lib/prompts.sh
source "$LIB_DIR/prompts.sh"
# shellcheck source=lib/preflight.sh
source "$LIB_DIR/preflight.sh"
# shellcheck source=lib/engine.sh
source "$LIB_DIR/engine.sh"
# shellcheck source=lib/manifest.sh
source "$LIB_DIR/manifest.sh"
# shellcheck source=lib/personal-cmd.sh
source "$LIB_DIR/personal-cmd.sh"
# shellcheck source=lib/memory.sh
source "$LIB_DIR/memory.sh"
# shellcheck source=lib/onboarding.sh
source "$LIB_DIR/onboarding.sh"
# shellcheck source=lib/configs.sh
source "$LIB_DIR/configs.sh"
# shellcheck source=lib/service.sh
source "$LIB_DIR/service.sh"
# shellcheck source=lib/oauth.sh
source "$LIB_DIR/oauth.sh"

main() {
  parse_args "$@"          # may exit on --help / --version; sets INSTANCE_NAME
                           # and re-runs desky_init_layout so paths reflect --name
  setup_logging            # only after we know we're really running
  detect_tty
  print_banner

  # Per-instance Claude state via CLAUDE_CONFIG_DIR (ADR 0006). Export
  # it now so install-time `claude` invocations (plugin install,
  # setup-token, status checks) all hit the per-instance dir and not
  # the user-wide default.
  export CLAUDE_CONFIG_DIR="$DESKY_CLAUDE_DIR"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "DRY-RUN — no system changes will be made"
  fi

  intro                    # welcome message + ENTER to continue

  preflight_os
  preflight_prereqs        # offers to install missing deps (node, jq)
  preflight_linger

  # Per-instance subdirectory tree. Every Phase 4 extension type lives
  # under one of these; create them all up front (empty placeholders
  # are fine) so subsequent steps + future skills/MCPs/hooks have a
  # known place to land.
  if [[ "$DRY_RUN" -ne 1 ]]; then
    mkdir -p \
      "$DESKY_INSTANCE_DIR" \
      "$DESKY_WORKSPACE" \
      "$DESKY_TELEGRAM" \
      "$DESKY_MCPS" \
      "$DESKY_SKILLS" \
      "$DESKY_HOOKS" \
      "$DESKY_DATA" \
      "$DESKY_CLAUDE_DIR"
  fi

  collect_inputs           # walks user through BotFather + userinfobot

  # Reject if the bot token is already used by another instance — only
  # safe to check after collect_inputs has populated BOT_TOKEN.
  check_bot_token_collision

  engine_install                                # install the engine binary
  engine_seed_state "$DESKY_WORKSPACE"       # skip theme + trust prompts
  engine_install_channel_plugin telegram        # marketplace + plugin
  write_configs
  write_service
  seed_persona                                  # starter CLAUDE.md (preserved)
  oauth_setup
  start_service

  # Manifest writes — every entrypoint reads these afterwards.
  manifest_register_instance "$INSTANCE_NAME"
  manifest_init_instance     "$INSTANCE_NAME"
  manifest_set_channel       "$INSTANCE_NAME" telegram ""

  # Personal command wrapper at ~/.local/bin/<INSTANCE_NAME>. After this
  # the operator says `<name> doctor` instead of repeating long flags.
  step "Install personal command"
  personal_cmd_install "$INSTANCE_NAME"

  final_summary
}

main "$@"
