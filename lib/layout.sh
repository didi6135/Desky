# lib/layout.sh — Claudify on-disk layout constants (per-instance, flat)
#
# Multi-instance, flat layout per ADR 0006:
#   ~/.claudify-<name>/                  ← one instance, fully self-contained
#   ~/.claudify-registry.json            ← side-car: list of all instances
#
# Each instance's bot runs in a private mount namespace (3.6.2) where
# only its own ~/.claudify-<name>/ folder is visible. Cross-instance
# reads/writes are kernel-blocked. CLAUDE_CONFIG_DIR points at the
# per-instance claude state dir so Claude Code's own settings,
# plugins, and project-trust files are isolated too.
#
# Path constants are computed from $INSTANCE_NAME. parse_args (args.sh)
# may override INSTANCE_NAME from `--name <NAME>`; the orchestrator
# (install.sh / update.sh / etc.) calls `claudify_init_layout` AFTER
# parse_args to pick up that override.
#
# Exposes:
#   INSTANCE_NAME             — default 'default'; --name overrides
#   CLAUDIFY_INSTANCE_DIR     — ~/.claudify-<name>  (top-level per instance)
#   CLAUDIFY_WORKSPACE        — <instance>/workspace
#   CLAUDIFY_TELEGRAM         — <instance>/channels/telegram
#   CLAUDIFY_MCPS             — <instance>/mcps
#   CLAUDIFY_SKILLS           — <instance>/skills
#   CLAUDIFY_HOOKS            — <instance>/hooks
#   CLAUDIFY_DATA             — <instance>/data
#   CLAUDIFY_CLAUDE_DIR       — <instance>/claude  (CLAUDE_CONFIG_DIR target)
#   CREDS_FILE                — <instance>/credentials.env (chmod 600)
#   CLAUDIFY_REGISTRY         — ~/.claudify-registry.json
#   claudify_init_layout      — (re-)compute the constants from $INSTANCE_NAME

# Default INSTANCE_NAME to the operator's Linux username (e.g. `david doctor`).
# Personal, memorable, and almost never collides with shell functions/builtins
# in practice. Falls back to 'claudify-bot' when whoami doesn't pass the regex
# (system accounts, uppercase usernames, etc.) or when it would collide with
# the validate.sh blocklist (e.g. an operator literally named 'default').
# Operators can always override via `--name <NAME>` or `INSTANCE_NAME=<NAME>`.
#
# layout.sh is sourced BEFORE validate.sh in install.sh — so this guard is
# inlined (regex + 'default' exclusion) rather than calling validate_instance_name.
_claudify_default_instance_name() {
  local who
  who="$(id -un 2>/dev/null || true)"
  if [[ "$who" =~ ^[a-z][a-z0-9_-]{1,30}$ ]] && [[ "$who" != "default" ]]; then
    printf '%s' "$who"
  else
    printf '%s' "claudify-bot"
  fi
}

INSTANCE_NAME="${INSTANCE_NAME:-$(_claudify_default_instance_name)}"

claudify_init_layout() {
  CLAUDIFY_INSTANCE_DIR="$HOME/.claudify-$INSTANCE_NAME"
  CLAUDIFY_WORKSPACE="$CLAUDIFY_INSTANCE_DIR/workspace"
  CLAUDIFY_TELEGRAM="$CLAUDIFY_INSTANCE_DIR/channels/telegram"
  CLAUDIFY_MCPS="$CLAUDIFY_INSTANCE_DIR/mcps"
  CLAUDIFY_SKILLS="$CLAUDIFY_INSTANCE_DIR/skills"
  CLAUDIFY_HOOKS="$CLAUDIFY_INSTANCE_DIR/hooks"
  CLAUDIFY_DATA="$CLAUDIFY_INSTANCE_DIR/data"
  CLAUDIFY_CLAUDE_DIR="$CLAUDIFY_INSTANCE_DIR/claude"
  CREDS_FILE="$CLAUDIFY_INSTANCE_DIR/credentials.env"
  CLAUDIFY_REGISTRY="$HOME/.claudify-registry.json"
}

# Initial pass with the default name. main() re-calls claudify_init_layout
# after parse_args has run, so a --name override is reflected.
claudify_init_layout
