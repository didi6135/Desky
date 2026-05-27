# lib/service.sh — systemd user unit + service start + final summary
#
# Per-instance unit name: desky-<INSTANCE_NAME>.service
# Per ADR 0006: bot runs in a private mount namespace where only its
# own ~/.desky-<name>/ folder is visible. Cross-instance reads
# kernel-blocked.
#
# The ExecStart command line comes from `engine_run_args` (engine
# adapter — 3.4.3). Today's only adapter is Claude Code, which wraps
# the run in /usr/bin/script for a real PTY.
#
# Constants `DESKY_INSTANCE_DIR`, `DESKY_WORKSPACE`, etc. come
# from lib/layout.sh. INSTANCE_NAME comes from lib/layout.sh /
# args.sh (--name override).
#
# Exposes:
#   write_service    — write + enable user systemd unit (idempotent)
#   start_service    — restart + verify it stayed up after 3 s
#   final_summary    — congratulatory output + useful commands
#   service_unit_name — echoes "desky-<INSTANCE_NAME>"

service_unit_name() {
  printf 'desky-%s' "$INSTANCE_NAME"
}

# ─── systemd user service ─────────────────────────────────────────────────
write_service() {
  step "Install systemd service"

  local svc_dir="$HOME/.config/systemd/user"
  local unit_name
  unit_name="$(service_unit_name)"
  local svc_path="$svc_dir/${unit_name}.service"

  run "mkdir -p '$svc_dir'"
  run "mkdir -p '$DESKY_WORKSPACE'"

  # Engine decides the ExecStart line — Claude Code wraps in script(1)
  # for a real PTY; future engines may do something else.
  local execstart
  execstart="$(engine_run_args)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [DRY] write $svc_path"
  else
    cat > "$svc_path" <<SVC
[Unit]
Description=Desky — Telegram bot ($INSTANCE_NAME)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
# All per-instance state lives under ~/.desky-${INSTANCE_NAME}/.
# Leading '-' on EnvironmentFile makes it optional so the unit can be
# written before oauth_setup populates credentials.env.
EnvironmentFile=-%h/.desky-${INSTANCE_NAME}/credentials.env
Environment=PATH=%h/.bun/bin:%h/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=HOME=%h
Environment=TERM=xterm-256color
Environment=TELEGRAM_STATE_DIR=%h/.desky-${INSTANCE_NAME}/channels/telegram
Environment=DESKY_INSTANCE_NAME=${INSTANCE_NAME}
Environment=DESKY_INSTANCE_DIR=%h/.desky-${INSTANCE_NAME}
Environment=CLAUDE_CONFIG_DIR=%h/.desky-${INSTANCE_NAME}/claude
WorkingDirectory=%h/.desky-${INSTANCE_NAME}/workspace

# === Tier-1 hardening (3.6.1) ===
# Only the directives that work in user-mode systemd on Ubuntu 24.04
# (verified on Station11 2026-05-10). They protect the host from a
# misbehaving bot (kernel state, fork-bomb, memory exhaustion) but
# do NOT isolate this bot from other instances on the same host.
# For cross-instance isolation, use containers (3.4.9).
#
# Excluded: directives that require CAP_SETPCAP to drop kernel
# capabilities (ProtectKernelModules, ProtectKernelLogs, ProtectClock,
# ProtectHostname) — user-mode systemd lacks the capability, so they
# fail with status=218/CAPABILITIES. Also excluded: mount-namespace
# directives (PrivateTmp, ProtectKernelTunables, ProtectControlGroups)
# — same AppArmor issue documented in ADR 0006 appendix.
NoNewPrivileges=true
RestrictSUIDSGID=true
LockPersonality=true
RestrictRealtime=true
RestrictNamespaces=true
MemoryMax=1G
TasksMax=200
LimitNPROC=200

ExecStart=$execstart
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
SVC
    ok "service unit written ($unit_name.service)"
  fi

  if [[ "$DRY_RUN" -ne 1 ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    systemctl --user daemon-reload
    systemctl --user enable "${unit_name}.service" >/dev/null 2>&1
    ok "service enabled"
  fi
}

# ─── Start service + verify ───────────────────────────────────────────────
start_service() {
  step "Start service"
  local unit_name
  unit_name="$(service_unit_name)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [DRY] systemctl --user restart $unit_name"
    return 0
  fi

  systemctl --user restart "${unit_name}.service"
  sleep 3

  if systemctl --user is-active --quiet "${unit_name}.service"; then
    ok "service is running"
  else
    warn "service failed to start. Last 20 log lines:"
    journalctl --user -u "$unit_name" -n 20 --no-pager | sed 's/^/    /'
    fail "Service did not stay up. Check logs above."
  fi
}

# ─── Final summary ────────────────────────────────────────────────────────
final_summary() {
  echo
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    c_yellow "╭────────────────────────────────────────────────────────────╮"
    banner_line "DRY-RUN complete  —  no changes were made" "\033[33m"
    c_yellow "╰────────────────────────────────────────────────────────────╯"
    echo
    echo "  Re-run without --dry-run to actually install:"
    echo "      bash install.sh"
    echo
    echo "  Dry-run log: $LOG_FILE"
    echo
    return
  fi

  # Install finished cleanly — drop the resume crumbs.
  clear_partial_state

  local unit_name
  unit_name="$(service_unit_name)"

  c_green "╭────────────────────────────────────────────────────────────╮"
  banner_line "Desky  —  install complete ($INSTANCE_NAME)" "\033[32m"
  c_green "╰────────────────────────────────────────────────────────────╯"
  echo
  echo "  Send a message to your bot on Telegram to test."
  echo
  echo "  Run any of these (personal command at ~/.local/bin/$INSTANCE_NAME):"
  echo "    $INSTANCE_NAME status        — service health"
  echo "    $INSTANCE_NAME logs          — follow logs"
  echo "    $INSTANCE_NAME doctor        — full diagnostic"
  echo "    $INSTANCE_NAME --help        — full list of subcommands"
  echo
  echo "  (If '$INSTANCE_NAME: command not found' — open a new terminal"
  echo "   or run 'source ~/.bashrc' to pick up the new PATH entry.)"
  echo
  echo "  Manifest files (what's installed):"
  echo "    Registry:       $DESKY_REGISTRY"
  echo "    This instance:  $DESKY_INSTANCE_DIR/desky.json"
  echo
  echo "  Install log: $LOG_FILE"
  echo
}
