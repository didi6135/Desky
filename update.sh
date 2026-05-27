#!/usr/bin/env bash
# update.sh — refresh a Desky instance to the latest main branch, in place.
#
# Usage (on the target server):
#   bash <(curl -fsSL https://raw.githubusercontent.com/didi6135/Claudify/main/update.sh)
#   bash <(curl -fsSL .../update.sh) --name client-a
#   bash <(curl -fsSL .../update.sh) --all          # update every registered instance
#   bash update.sh
#
# What it does (per instance):
#   Fetches the latest dist/install.sh from main and runs it with
#   --preserve-state --non-interactive --name <NAME>. That means:
#     • BOT_TOKEN (~/.desky-<n>/channels/telegram/.env)   — preserved
#     • TG_USER_ID allowlist (access.json)                    — preserved
#     • CLAUDE_CODE_OAUTH_TOKEN (credentials.env)             — preserved
#     • systemd unit file                                      — rewritten
#     • per-instance Claude state                              — reseeded
#     • claude plugin + bun                                    — updated if available
#     • service                                                — restarted
#
# Typically takes 10-20s on a healthy instance. No OAuth prompts, no
# questions.
#
# If no Desky install exists, this script tells you to run install.sh.

set -euo pipefail

INSTANCE_NAME="default"
ALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      [[ $# -lt 2 ]] && { echo "--name requires a value" >&2; exit 1; }
      INSTANCE_NAME="$2"; shift 2 ;;
    --all) ALL=1; shift ;;
    -h|--help)
      cat <<HELP
Desky update.sh

Usage:
  bash update.sh                    Update the 'default' instance
  bash update.sh --name <NAME>      Update a specific named instance
  bash update.sh --all              Update every registered instance

What's preserved across update:
  bot token, allowlist, OAuth credentials, persona (CLAUDE.md edits).
What's refreshed:
  systemd unit, claude binary + plugin, ~/.claude state seed, service restart.
HELP
      exit 0 ;;
    *) echo "Unknown flag: $1 (try --help)" >&2; exit 1 ;;
  esac
done

REGISTRY="$HOME/.desky-registry.json"

# Refuse if no Desky install exists at all.
if [[ ! -s "$REGISTRY" ]]; then
  # Legacy fallback: pre-3.4.5 single-instance layout at ~/.desky/
  if [[ -d "$HOME/.desky" ]]; then
    echo "Detected pre-3.4.5 single-instance layout at ~/.desky/."
    echo "3.4.5 changes the layout to ~/.desky-<name>/ — migration is the"
    echo "job of 3.4.7 (not yet released). Until then, please uninstall first:"
    echo "    bash <(curl -fsSL https://raw.githubusercontent.com/didi6135/Claudify/main/uninstall.sh) --yes"
    echo "Then reinstall:"
    echo "    curl -fsSL https://raw.githubusercontent.com/didi6135/Claudify/main/dist/install.sh | bash"
    exit 1
  fi
  echo "No Desky install found (no $REGISTRY)."
  echo
  echo "This script updates an existing install. For a first-time install, run:"
  echo
  echo "    curl -fsSL https://raw.githubusercontent.com/didi6135/Claudify/main/dist/install.sh | bash"
  echo
  exit 1
fi

# Cache-bust the dist URL — raw.githubusercontent.com has CDN edges
# that sometimes serve a stale copy for minutes after a push.
DIST_URL="https://raw.githubusercontent.com/didi6135/Claudify/main/dist/install.sh?t=$(date +%s)"

run_update() {
  local name="$1"
  local instance_dir="$HOME/.desky-$name"
  if [[ ! -d "$instance_dir" ]]; then
    echo "Instance '$name' not found at $instance_dir — skipping."
    return 0
  fi
  echo
  echo "=== Updating instance '$name' ==="
  curl -fsSL "$DIST_URL" \
    | bash -s -- --preserve-state --name "$name"
}

if [[ "$ALL" -eq 1 ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "--all requires jq to read the registry. Install with: apt install jq" >&2
    exit 1
  fi
  while IFS= read -r name; do
    run_update "$name"
  done < <(jq -r '.instances | keys[]' "$REGISTRY")
else
  run_update "$INSTANCE_NAME"
fi
