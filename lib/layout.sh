# lib/layout.sh — Desky on-disk layout constants (per-instance, flat)
#
# Multi-instance, flat layout per ADR 0006:
#   ~/.desky-<name>/                  ← one instance, fully self-contained
#   ~/.desky-registry.json            ← side-car: list of all instances
#
# Each instance's bot runs in a private mount namespace (3.6.2) where
# only its own ~/.desky-<name>/ folder is visible. Cross-instance
# reads/writes are kernel-blocked. CLAUDE_CONFIG_DIR points at the
# per-instance claude state dir so Claude Code's own settings,
# plugins, and project-trust files are isolated too.
#
# Path constants are computed from $INSTANCE_NAME. parse_args (args.sh)
# may override INSTANCE_NAME from `--name <NAME>`; the orchestrator
# (install.sh / update.sh / etc.) calls `desky_init_layout` AFTER
# parse_args to pick up that override.
#
# Exposes:
#   INSTANCE_NAME             — default 'default'; --name overrides
#   DESKY_INSTANCE_DIR     — ~/.desky-<name>  (top-level per instance)
#   DESKY_WORKSPACE        — <instance>/workspace
#   DESKY_TELEGRAM         — <instance>/channels/telegram
#   DESKY_MCPS             — <instance>/mcps
#   DESKY_SKILLS           — <instance>/skills
#   DESKY_HOOKS            — <instance>/hooks
#   DESKY_DATA             — <instance>/data
#   DESKY_CLAUDE_DIR       — <instance>/claude  (CLAUDE_CONFIG_DIR target)
#   CREDS_FILE                — <instance>/credentials.env (chmod 600)
#   DESKY_REGISTRY         — ~/.desky-registry.json
#   desky_init_layout      — (re-)compute the constants from $INSTANCE_NAME

# Default INSTANCE_NAME to the operator's Linux username (e.g. `david doctor`).
# Personal, memorable, and almost never collides with shell functions/builtins
# in practice. Falls back to 'desky-bot' when whoami doesn't pass the regex
# (system accounts, uppercase usernames, etc.) or when it would collide with
# the validate.sh blocklist (e.g. an operator literally named 'default').
# Operators can always override via `--name <NAME>` or `INSTANCE_NAME=<NAME>`.
#
# layout.sh is sourced BEFORE validate.sh in install.sh — so this guard is
# inlined (regex + 'default' exclusion) rather than calling validate_instance_name.
_desky_default_instance_name() {
  local who
  who="$(id -un 2>/dev/null || true)"
  if [[ "$who" =~ ^[a-z][a-z0-9_-]{1,30}$ ]] && [[ "$who" != "default" ]]; then
    printf '%s' "$who"
  else
    printf '%s' "desky-bot"
  fi
}

INSTANCE_NAME="${INSTANCE_NAME:-$(_desky_default_instance_name)}"

desky_init_layout() {
  DESKY_INSTANCE_DIR="$HOME/.desky-$INSTANCE_NAME"
  DESKY_WORKSPACE="$DESKY_INSTANCE_DIR/workspace"
  DESKY_TELEGRAM="$DESKY_INSTANCE_DIR/channels/telegram"
  DESKY_MCPS="$DESKY_INSTANCE_DIR/mcps"
  DESKY_SKILLS="$DESKY_INSTANCE_DIR/skills"
  DESKY_HOOKS="$DESKY_INSTANCE_DIR/hooks"
  DESKY_DATA="$DESKY_INSTANCE_DIR/data"
  DESKY_CLAUDE_DIR="$DESKY_INSTANCE_DIR/claude"
  CREDS_FILE="$DESKY_INSTANCE_DIR/credentials.env"
  DESKY_REGISTRY="$HOME/.desky-registry.json"
}

# Initial pass with the default name. main() re-calls desky_init_layout
# after parse_args has run, so a --name override is reflected.
desky_init_layout
