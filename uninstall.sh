#!/usr/bin/env bash
# uninstall.sh — remove a Claudify instance from this server.
#
# Usage:
#   bash <(curl -fsSL .../uninstall.sh) --name <NAME> --yes
#   bash <(curl -fsSL .../uninstall.sh) --all --yes
#   bash uninstall.sh --name client-a
#   bash uninstall.sh --help
#
# What gets removed (per instance):
#   • systemd user service (claudify-<NAME>.service), stopped + disabled
#   • ~/.config/systemd/user/claudify-<NAME>.service (the unit file)
#   • ~/.claudify-<NAME>/ (ALL per-instance state: tokens, workspace,
#                         persona, channels, MCPs, skills, hooks, data,
#                         per-instance Claude state)
#   • the instance's entry in ~/.claudify-registry.json
#
# Removing the LAST instance also removes ~/.claudify-registry.json.
#
# What stays (the operator may have other uses — remove manually if desired):
#   • ~/.bun/                      Bun runtime
#   • ~/.npm-global/               npm global prefix (where `claude` lives)
#   • ~/.claude/                   Claude Code's host-wide state (if any
#                                  pre-3.4.5 install left it; 3.4.5+ uses
#                                  per-instance ~/.claudify-<name>/claude/)
#   • ~/.claude.json               Pre-3.4.5 host-wide state (same)
#   • loginctl linger (if on)

set -uo pipefail   # NOT -e: we want to continue past missing files

# ─── Output helpers ───────────────────────────────────────────────────────
c_red()    { printf '\033[31m%s\033[0m\n' "$*"; }
c_green()  { printf '\033[32m%s\033[0m\n' "$*"; }
c_yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
c_cyan()   { printf '\033[36m%s\033[0m\n' "$*"; }
c_bold()   { printf '\033[1m%s\033[0m\n'  "$*"; }

section() { echo; c_cyan "━━━ $* ━━━"; echo; }
ok()   { echo "  $(c_green '✓') $*"; }
skip() { echo "  $(c_yellow '·') $*"; }
warn() { echo "  $(c_yellow '⚠') $*"; }
fail() { echo "  $(c_red   '✗') $*"; exit 1; }

# ─── Args ─────────────────────────────────────────────────────────────────
INSTANCE_NAME=""
ALL=0
ASSUME_YES=0

show_help() {
  cat <<HELP
Claudify uninstall.sh

Usage:
  bash uninstall.sh --name <NAME>       Remove one named instance
  bash uninstall.sh --name <NAME> --yes No confirmation prompt
  bash uninstall.sh --all               Remove every registered instance
  bash uninstall.sh --help              This help

Removes (per instance):
  • claudify-<NAME>.service (stopped + disabled + unit file deleted)
  • ~/.claudify-<NAME>/      (all per-instance state)
  • that instance's entry in ~/.claudify-registry.json

Leaves untouched:
  ~/.bun/, ~/.npm-global/, ~/.claude/ (pre-3.4.5), linger.
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      [[ $# -lt 2 ]] && fail "--name requires a value"
      INSTANCE_NAME="$2"; shift 2 ;;
    --all)     ALL=1; shift ;;
    --yes|-y)  ASSUME_YES=1; shift ;;
    --help|-h) show_help; exit 0 ;;
    *) fail "Unknown flag: $1 (try --help)" ;;
  esac
done

REGISTRY="$HOME/.claudify-registry.json"

# Build the list of instances to uninstall.
INSTANCES=()
if [[ "$ALL" -eq 1 ]]; then
  if [[ ! -s "$REGISTRY" ]]; then
    # Fall back to globbing top-level dirs.
    shopt -s nullglob
    for d in "$HOME"/.claudify-*/; do
      name="${d##*/.claudify-}"; name="${name%/}"
      INSTANCES+=("$name")
    done
    shopt -u nullglob
  else
    if command -v jq >/dev/null 2>&1; then
      while IFS= read -r n; do INSTANCES+=("$n"); done < <(jq -r '.instances | keys[]' "$REGISTRY")
    else
      shopt -s nullglob
      for d in "$HOME"/.claudify-*/; do
        name="${d##*/.claudify-}"; name="${name%/}"
        INSTANCES+=("$name")
      done
      shopt -u nullglob
    fi
  fi
elif [[ -n "$INSTANCE_NAME" ]]; then
  INSTANCES=("$INSTANCE_NAME")
else
  # Bare invocation — refuse, list what's available so operator knows.
  echo "uninstall.sh requires --name <NAME> or --all."
  echo
  if [[ -s "$REGISTRY" ]] && command -v jq >/dev/null 2>&1; then
    echo "Registered instances on this host:"
    jq -r '.instances | to_entries[] | "  • \(.key)  (engine=\(.value.engine), service=\(.value.service))"' "$REGISTRY"
  else
    shopt -s nullglob
    found=0
    for d in "$HOME"/.claudify-*/; do
      [[ "$found" -eq 0 ]] && echo "Detected by directory glob:"
      found=1
      name="${d##*/.claudify-}"; name="${name%/}"
      echo "  • $name"
    done
    shopt -u nullglob
    [[ "$found" -eq 0 ]] && echo "(no instances found on this host)"
  fi
  echo
  echo "Examples:"
  echo "  bash uninstall.sh --name default --yes"
  echo "  bash uninstall.sh --all --yes"
  exit 1
fi

if [[ ${#INSTANCES[@]} -eq 0 ]]; then
  echo "No instances to remove."
  exit 0
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# ─── Preview ──────────────────────────────────────────────────────────────
c_bold "╭────────────────────────────────────────────────────────────╮"
c_bold "│              Claudify  —  uninstall                        │"
c_bold "╰────────────────────────────────────────────────────────────╯"

echo
echo "  Will remove ${#INSTANCES[@]} instance(s):"
for name in "${INSTANCES[@]}"; do
  unit="claudify-${name}.service"
  unit_file="$HOME/.config/systemd/user/${unit}"
  inst_dir="$HOME/.claudify-${name}"
  size="?"
  [[ -d "$inst_dir" ]] && size=$(du -sh "$inst_dir" 2>/dev/null | cut -f1)
  echo "    • $name"
  echo "        service: $unit  (active: $(systemctl --user is-active "$unit" 2>/dev/null || echo no))"
  echo "        unit:    $unit_file"
  echo "        dir:     $inst_dir  (${size})"
done
echo

# ─── Confirm ──────────────────────────────────────────────────────────────
if [[ "$ASSUME_YES" -ne 1 ]]; then
  if [[ -t 0 ]]; then TTY=/dev/stdin
  elif [[ -r /dev/tty && -w /dev/tty ]]; then TTY=/dev/tty
  else fail "Non-interactive run with no --yes. Re-run with --yes to proceed."; fi
  read -r -p "  Proceed? [y/N]: " reply < "$TTY"
  [[ "$reply" =~ ^[Yy]$ ]] || { echo; c_yellow "  Aborted. Nothing removed."; exit 0; }
fi

# ─── Remove ───────────────────────────────────────────────────────────────
section "Removing"

for name in "${INSTANCES[@]}"; do
  unit="claudify-${name}.service"
  unit_file="$HOME/.config/systemd/user/${unit}"
  inst_dir="$HOME/.claudify-${name}"

  echo
  c_bold "  ── $name ──"

  # 1. Stop + disable the service
  if systemctl --user list-unit-files "$unit" 2>/dev/null | grep -q "$unit"; then
    systemctl --user stop "$unit" 2>/dev/null
    systemctl --user disable "$unit" 2>/dev/null
    ok "service stopped + disabled"
  else
    skip "service already gone"
  fi

  # 2. Remove the unit file
  if [[ -f "$unit_file" ]]; then
    rm -f "$unit_file" && ok "unit file removed"
  else
    skip "unit file already gone"
  fi

  # 3. Remove the per-instance dir
  if [[ -d "$inst_dir" ]]; then
    rm -rf "$inst_dir" && ok "$inst_dir removed"
  else
    skip "$inst_dir already gone"
  fi

  # 4. Drop the registry entry
  if [[ -s "$REGISTRY" ]] && command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp)"
    jq --arg n "$name" 'del(.instances[$n])' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
    ok "registry entry removed"
  fi
done

# Reload systemd once after all removals
systemctl --user daemon-reload 2>/dev/null && ok "systemctl daemon-reload" || skip "daemon-reload skipped (no user bus)"

# Empty registry → remove the file itself
if [[ -s "$REGISTRY" ]] && command -v jq >/dev/null 2>&1; then
  if [[ "$(jq -r '.instances | length' "$REGISTRY")" == "0" ]]; then
    rm -f "$REGISTRY" && ok "registry file removed (no instances left)"
  fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────
section "Done"

c_green "  Claudify instance(s) removed."
echo
echo "  Left untouched (remove manually if you want a completely clean system):"
for p in "$HOME/.bun" "$HOME/.npm-global" "$HOME/.claude" "$HOME/.claude.json"; do
  [[ -e "$p" ]] && echo "    rm -rf $p"
done

linger=$(loginctl show-user "$USER" 2>/dev/null | grep '^Linger=' | cut -d= -f2 || true)
if [[ "$linger" == "yes" ]]; then
  echo "    sudo loginctl disable-linger $USER"
fi
echo
echo "  To reinstall later:"
echo "    curl -fsSL https://raw.githubusercontent.com/didi6135/Claudify/main/dist/install.sh | bash"
echo
