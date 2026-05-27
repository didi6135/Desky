#!/usr/bin/env bash
# doctor.sh — diagnose a Desky install on the server it runs on.
#
# Usage (from the target server):
#   bash <(curl -fsSL https://raw.githubusercontent.com/didi6135/Claudify/main/doctor.sh)
#   bash doctor.sh                       (default: pick from registry / default)
#   bash doctor.sh --name client-a       (named instance)
#   bash doctor.sh --all                 (every registered instance)
#
# Read-only. Runs as the user who owns the install (no sudo).

set -uo pipefail

# ─── Output helpers ───────────────────────────────────────────────────────
c_red()    { printf '\033[31m%s\033[0m\n' "$*"; }
c_green()  { printf '\033[32m%s\033[0m\n' "$*"; }
c_yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
c_cyan()   { printf '\033[36m%s\033[0m\n' "$*"; }
c_bold()   { printf '\033[1m%s\033[0m\n'  "$*"; }

PASS=0; WARN=0; FAIL=0

section() { echo; c_cyan "━━━ $* ━━━"; echo; }

check() {
  local desc="$1" status="$2"; shift 2
  case "$status" in
    0) echo "  $(c_green '✓') $desc"; PASS=$((PASS+1)) ;;
    1) echo "  $(c_red   '✗') $desc"; FAIL=$((FAIL+1))
       for line in "$@"; do echo "    → $line"; done ;;
    2) echo "  $(c_yellow '⚠') $desc"; WARN=$((WARN+1))
       for line in "$@"; do echo "    → $line"; done ;;
  esac
}

# ─── Args ─────────────────────────────────────────────────────────────────
INSTANCE_NAME=""
ALL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) INSTANCE_NAME="$2"; shift 2 ;;
    --all)  ALL=1; shift ;;
    -h|--help)
      cat <<HELP
Desky doctor.sh

Usage:
  bash doctor.sh                  Pick from registry, or 'default' if alone
  bash doctor.sh --name <NAME>    Check a specific named instance
  bash doctor.sh --all            Check every registered instance
HELP
      exit 0 ;;
    *) echo "Unknown flag: $1 (try --help)" >&2; exit 1 ;;
  esac
done

REGISTRY_FILE="$HOME/.desky-registry.json"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PATH="$HOME/.bun/bin:$HOME/.npm-global/bin:$PATH"

# ─── Pick instance(s) to check ────────────────────────────────────────────
INSTANCES=()
if [[ "$ALL" -eq 1 ]]; then
  if [[ -s "$REGISTRY_FILE" ]] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r n; do INSTANCES+=("$n"); done < <(jq -r '.instances | keys[]' "$REGISTRY_FILE")
  fi
elif [[ -n "$INSTANCE_NAME" ]]; then
  INSTANCES=("$INSTANCE_NAME")
else
  # No flag: pick from registry, fall back to 'default'
  if [[ -s "$REGISTRY_FILE" ]] && command -v jq >/dev/null 2>&1; then
    count=$(jq '.instances | length' "$REGISTRY_FILE")
    if [[ "$count" -eq 1 ]]; then
      INSTANCES=("$(jq -r '.instances | keys[0]' "$REGISTRY_FILE")")
    elif [[ "$count" -gt 1 ]]; then
      c_yellow "Multiple instances registered. Listing summary; use --name <NAME> for full check."
      jq -r '.instances | to_entries[] | "  • \(.key)  (engine=\(.value.engine), service=\(.value.service))"' "$REGISTRY_FILE"
      INSTANCES=("$(jq -r '.instances | keys[0]' "$REGISTRY_FILE")")
      echo
      c_yellow "Running full check for: ${INSTANCES[0]}"
    fi
  fi
  [[ ${#INSTANCES[@]} -eq 0 ]] && INSTANCES=("default")
fi

# ─── Banner ───────────────────────────────────────────────────────────────
c_bold "╭────────────────────────────────────────────────────────────╮"
c_bold "│                  Desky  —  doctor                       │"
c_bold "╰────────────────────────────────────────────────────────────╯"

# ─── Per-host checks (run once) ───────────────────────────────────────────
section "Environment"
if [[ "$(uname -s)" == "Linux" ]]; then
  check "Linux host ($(uname -m))" 0
else
  check "Not Linux — this server cannot host the bot" 1 \
    "Desky installs require a Linux server with systemd."
fi
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  check "OS: ${PRETTY_NAME:-unknown}" 0
fi
check "Running as user: $USER (uid $(id -u))" 0

section "Dependencies"
command -v node    >/dev/null 2>&1 && check "node $(node --version)"  0 || check "node missing"   1 "Install Node.js 20+"
command -v npm     >/dev/null 2>&1 && check "npm $(npm --version)"    0 || check "npm missing"    1 "Install npm"
command -v bun     >/dev/null 2>&1 && check "bun $(bun --version)"    0 || check "bun missing"    1 "curl -fsSL https://bun.sh/install | bash"
command -v jq      >/dev/null 2>&1 && check "jq present"              0 || check "jq missing"     1 "Install jq via apt"
command -v claude  >/dev/null 2>&1 && check "claude $(claude --version 2>/dev/null | head -1)" 0 || check "claude missing" 1 "npm install -g @anthropic-ai/claude-code"
[[ -x /usr/bin/script ]]            && check "/usr/bin/script (util-linux)" 0 || check "/usr/bin/script missing" 1 "sudo apt install -y util-linux"

linger=$(loginctl show-user "$USER" 2>/dev/null | grep '^Linger=' | cut -d= -f2 || true)
if [[ "$linger" == "yes" ]]; then
  check "linger enabled for $USER" 0
else
  check "linger disabled — service dies on logout" 1 "sudo loginctl enable-linger $USER"
fi

# ─── Per-instance checks ──────────────────────────────────────────────────
check_instance() {
  local name="$1"
  local instance_dir="$HOME/.desky-$name"
  local workspace="$instance_dir/workspace"
  local telegram="$instance_dir/channels/telegram"
  local creds="$instance_dir/credentials.env"
  local claude_dir="$instance_dir/claude"
  local manifest="$instance_dir/desky.json"
  local unit_name="desky-$name"
  local unit_file="$HOME/.config/systemd/user/${unit_name}.service"

  # Load OAuth token for claude auth checks
  if [[ -s "$creds" ]]; then
    set -a; . "$creds"; set +a
  fi
  # Per-instance Claude config dir
  export CLAUDE_CONFIG_DIR="$claude_dir"

  section "Instance '$name'  ($instance_dir)"
  if [[ -d "$instance_dir" ]]; then
    check "instance dir exists" 0
  else
    check "instance dir missing" 1 "Run install.sh --name $name"
    return
  fi

  # Layout subdirs
  for sub in workspace channels mcps skills hooks data claude; do
    [[ -d "$instance_dir/$sub" ]] && check "$sub/ exists" 0 || check "$sub/ missing" 1 "Re-run install.sh --name $name"
  done

  # Secrets at rest
  if [[ -s "$creds" ]]; then
    perms=$(stat -c '%a' "$creds")
    if [[ "$perms" == "600" ]]; then check "credentials.env mode 600" 0
    else check "credentials.env mode $perms (expected 600)" 2 "chmod 600 $creds"; fi
  else
    check "credentials.env missing" 1 "Re-run install.sh --name $name (OAuth token never persisted)"
  fi

  if [[ -s "$telegram/.env" ]]; then
    perms=$(stat -c '%a' "$telegram/.env")
    [[ "$perms" == "600" ]] && check "channels/telegram/.env mode 600" 0 \
                            || check "channels/telegram/.env mode $perms (expected 600)" 2 "chmod 600 $telegram/.env"
  else
    check "channels/telegram/.env missing (bot token)" 1 "Re-run install.sh --name $name"
  fi

  if [[ -s "$telegram/access.json" ]]; then
    if jq -e 'has("allowFrom")' "$telegram/access.json" >/dev/null 2>&1; then
      n=$(jq '.allowFrom | length' "$telegram/access.json")
      check "access.json valid ($n allowlisted user(s))" 0
    else
      check "access.json missing 'allowFrom' key" 1 "Re-run install.sh --name $name"
    fi
  else
    check "access.json missing" 1 "Re-run install.sh --name $name"
  fi

  # Manifest
  if [[ -s "$manifest" ]]; then
    if jq -e 'has("name") and has("engine") and has("channels")' "$manifest" >/dev/null 2>&1; then
      iname=$(jq -r '.name' "$manifest"); iengine=$(jq -r '.engine' "$manifest")
      n_ch=$(jq '.channels | length' "$manifest")
      check "desky.json valid (name=$iname, engine=$iengine, $n_ch channel(s))" 0
    else
      check "desky.json missing required fields" 1 "Re-run install.sh --name $name"
    fi
  else
    check "desky.json missing" 1 "Re-run install.sh --name $name"
  fi

  # Per-instance Claude state (CLAUDE_CONFIG_DIR target)
  if [[ -s "$claude_dir/.claude.json" ]]; then
    if jq -e '.hasCompletedOnboarding == true' "$claude_dir/.claude.json" >/dev/null 2>&1; then
      check "onboarding seeded ($claude_dir/.claude.json)" 0
    else
      check "onboarding not seeded — service may hang" 1 "Re-run install.sh --name $name"
    fi
    if jq -e --arg d "$workspace" '.projects[$d].hasTrustDialogAccepted == true' "$claude_dir/.claude.json" >/dev/null 2>&1; then
      check "workspace trust set for $workspace" 0
    else
      check "workspace trust NOT set" 1 "Re-run install.sh --name $name"
    fi
  else
    check "$claude_dir/.claude.json missing" 1 "Re-run install.sh --name $name"
  fi

  if command -v claude >/dev/null 2>&1; then
    if claude auth status 2>&1 | grep -qE '"loggedIn"[[:space:]]*:[[:space:]]*true'; then
      check "Claude authenticated" 0
    else
      check "Claude NOT authenticated — API calls will 401" 1 \
        "Make sure $creds has CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-…"
    fi
  fi

  # Systemd unit
  if [[ -f "$unit_file" ]]; then
    check "unit file present ($unit_name.service)" 0
    grep -q "^EnvironmentFile=-%h/.desky-${name}/credentials.env" "$unit_file" \
      && check "unit references the per-instance credentials.env" 0 \
      || check "unit EnvironmentFile mismatch" 2 "Re-run install.sh --name $name"
    grep -q "^Environment=CLAUDE_CONFIG_DIR=%h/.desky-${name}/claude" "$unit_file" \
      && check "unit sets CLAUDE_CONFIG_DIR per-instance" 0 \
      || check "unit missing CLAUDE_CONFIG_DIR" 2 "Re-run install.sh --name $name"
    # Tier-1 hardening (the directives that actually work on Ubuntu 24.04 user-mode)
    local tier1=(NoNewPrivileges RestrictSUIDSGID LockPersonality RestrictRealtime RestrictNamespaces MemoryMax TasksMax LimitNPROC)
    local missing=()
    for d in "${tier1[@]}"; do
      grep -qE "^${d}=" "$unit_file" || missing+=("$d")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
      check "Tier-1 hardening directives present" 0
    else
      check "Tier-1 hardening: ${#missing[@]} directive(s) missing" 2 \
        "Missing: ${missing[*]}" "Re-run install.sh --name $name"
    fi
  else
    check "unit file missing ($unit_file)" 1 "Re-run install.sh --name $name"
  fi

  if systemctl --user is-enabled "$unit_name" >/dev/null 2>&1; then
    check "service enabled" 0
  else
    check "service not enabled" 2 "systemctl --user enable $unit_name"
  fi

  if systemctl --user is-active --quiet "$unit_name"; then
    started=$(systemctl --user show "$unit_name" --property=ActiveEnterTimestamp --value)
    check "service is active (since: $started)" 0
    svc_pid=$(systemctl --user show "$unit_name" --property=MainPID --value)
    if [[ -n "$svc_pid" && "$svc_pid" != "0" ]] && pstree -p "$svc_pid" 2>/dev/null | grep -q 'bun'; then
      check "bun MCP subprocess is running" 0
    else
      check "bun subprocess not found — plugin likely failed to start" 1 \
        "journalctl --user -u $unit_name -n 50 --no-pager"
    fi
  else
    check "service is NOT running" 1 "journalctl --user -u $unit_name -n 50 --no-pager"
  fi

  # Telegram reachability (only if we have a token)
  if [[ -s "$telegram/.env" ]]; then
    local TBOT
    TBOT="$(grep '^TELEGRAM_BOT_TOKEN=' "$telegram/.env" | cut -d= -f2-)"
    if [[ -n "$TBOT" ]]; then
      bot_info=$(curl -s --max-time 10 "https://api.telegram.org/bot${TBOT}/getMe")
      if echo "$bot_info" | grep -q '"ok":true'; then
        username=$(echo "$bot_info" | grep -oE '"username":"[^"]+"' | head -1 | cut -d'"' -f4)
        check "bot token valid (@${username:-?})" 0
      else
        check "Telegram rejected the bot token" 1 "Revoke + reissue via @BotFather"
      fi
      updates=$(curl -s --max-time 5 "https://api.telegram.org/bot${TBOT}/getUpdates?timeout=1")
      if echo "$updates" | grep -q '"error_code":409'; then
        check "service is actively polling (409 from getUpdates as expected)" 0
      elif echo "$updates" | grep -q '"ok":true'; then
        check "no one is polling Telegram — service isn't connected" 1 "journalctl --user -u $unit_name -n 100 --no-pager"
      fi
    fi
  fi
}

# ─── Run ──────────────────────────────────────────────────────────────────
for name in "${INSTANCES[@]}"; do
  check_instance "$name"
done

# ─── Summary ──────────────────────────────────────────────────────────────
echo
total=$((PASS + WARN + FAIL))
if (( FAIL == 0 && WARN == 0 )); then
  c_green "╭────────────────────────────────────────────────────────────╮"
  c_green "│                 All $total checks passed.                       │"
  c_green "╰────────────────────────────────────────────────────────────╯"
  echo; echo "  Your bot(s) should be fully operational."; echo
  exit 0
elif (( FAIL == 0 )); then
  c_yellow "╭────────────────────────────────────────────────────────────╮"
  c_yellow "│           $PASS passed, $WARN warnings, 0 failures.                │"
  c_yellow "╰────────────────────────────────────────────────────────────╯"
  echo; echo "  Bot should work, but the warnings above are worth addressing."; echo
  exit 0
else
  c_red "╭────────────────────────────────────────────────────────────╮"
  c_red "│      $PASS passed, $WARN warnings, $FAIL failure(s) — fix above.       │"
  c_red "╰────────────────────────────────────────────────────────────╯"
  echo; echo "  Fix each ✗ above (hints inline) and re-run doctor."; echo
  exit 1
fi
