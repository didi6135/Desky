# lib/personal-cmd.sh — personal command wrapper at ~/.local/bin/<name>
#
# After install the operator runs `<name> doctor`, `<name> update`,
# `<name> status`, etc. — short, ergonomic per-instance commands
# instead of long `bash uninstall.sh --name <name>` invocations
# (docs/architecture.md §3d).
#
# The wrapper dispatches to:
#   • `bash <(curl …doctor.sh|update.sh|uninstall.sh) --name <name>` —
#     fetches the latest entrypoint from origin so the operator always
#     runs the current one (mirrors how update.sh already works).
#   • `systemctl --user … claudify-<name>` for status/logs/start/stop/
#     restart (local-only, no network).
#
# Engine-agnostic: nothing here references `claude` or any engine
# adapter — the wrapper only deals with systemctl + Claudify entrypoints.
#
# Exposes:
#   personal_cmd_install <name>     — generate wrapper + ensure PATH
#   personal_cmd_uninstall <name>   — remove wrapper file (idempotent)
#   personal_cmd_ensure_path        — add ~/.local/bin to PATH in rc files
#   personal_cmd_clean_path         — remove the PATH line on full uninstall
#   personal_cmd_collision_check    — warn if <name> would be shadowed by an
#                                     existing PATH binary or zsh function
#                                     (Claudify-e4a — OMZ default() lesson)

CLAUDIFY_PATH_MARKER='# Claudify PATH —'
CLAUDIFY_RAW_BASE='https://raw.githubusercontent.com/didi6135/Claudify/main'

# personal_cmd_collision_check <name>
#   Warn (don't fail) if invoking <name> in the operator's interactive shell
#   would NOT reach ~/.local/bin/<name>. Two collision modes today:
#     1. Another binary earlier in PATH (e.g. /usr/bin/<name>)
#     2. A shell function/alias defined in the user's $SHELL (e.g. Oh My
#        Zsh's no-op default() in ~/.oh-my-zsh/lib/functions.zsh — the
#        original Claudify-e4a bug).
#   Functions beat PATH in zsh, so check 2 is the load-bearing one. We only
#   probe zsh (not bash) because bash function-shadowing of new wrappers in
#   practice never happens — bash users rarely define functions matching
#   short instance names, while OMZ does this by default.
#   Returns 0 if no collision (or only colliding with our own wrapper on
#   re-install); 1 if a real shadow was found. Prints details either way.
personal_cmd_collision_check() {
  local name="${1:?personal_cmd_collision_check: name required}"
  local own_wrapper="$HOME/.local/bin/$name"
  local collided=0

  # Check 1 — PATH binary. Re-install of our own wrapper is not a collision.
  local existing
  if existing="$(command -v "$name" 2>/dev/null)" && [[ -n "$existing" ]]; then
    if [[ "$existing" != "$own_wrapper" ]]; then
      warn "name '$name' already resolves to: $existing"
      warn "  → wrapper at $own_wrapper would NOT be picked up via bare '$name'."
      collided=1
    fi
  fi

  # Check 2 — zsh function (OMZ + plugins). Skip if user doesn't run zsh.
  local shell_bin
  shell_bin="${SHELL:-/bin/bash}"
  if [[ "$(basename "$shell_bin")" == "zsh" ]] && command -v zsh >/dev/null 2>&1; then
    # `(( $+functions[name] ))` is zsh-only; arithmetic, exits 0 if defined.
    if zsh -ic "(( \$+functions[$name] ))" 2>/dev/null; then
      warn "name '$name' is a zsh shell function (likely Oh My Zsh) — would shadow the wrapper."
      collided=1
    fi
  fi

  if [[ "$collided" -eq 1 ]]; then
    warn "  Workaround: invoke via full path '$own_wrapper <cmd>' or 'command $name <cmd>'."
    warn "  Or re-install with --name <something-else>, e.g. --name ${name}bot."
    return 1
  fi
  return 0
}

# personal_cmd_install <name>
#   Write the wrapper to ~/.local/bin/<name>, chmod 755, ensure PATH.
#   Honours DRY_RUN. Idempotent — overwrites an existing wrapper so
#   updates regenerate it cleanly. Runs personal_cmd_collision_check as
#   a non-fatal warning so the operator finds out at install time, not
#   when a confused 'foo doctor' silently no-ops in their shell weeks later.
personal_cmd_install() {
  local name="${1:?personal_cmd_install: name required}"
  local target_dir="$HOME/.local/bin"
  local target="$target_dir/$name"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "  [DRY] write $target"
    echo "  [DRY] ensure ~/.local/bin in PATH (~/.bashrc, ~/.zshrc)"
    echo "  [DRY] collision-check '$name' against PATH + user shell"
    return 0
  fi

  mkdir -p "$target_dir"
  _personal_cmd_write_wrapper "$name" > "$target"
  chmod 755 "$target"
  ok_done "personal command installed: ~/.local/bin/$name"

  # Warn (don't fail) if the wrapper would be shadowed in the operator's
  # interactive shell. They still have the wrapper at full path; this just
  # makes the failure mode visible NOW rather than in week-3 confusion.
  personal_cmd_collision_check "$name" || true

  personal_cmd_ensure_path

  # If the current shell hasn't picked up ~/.local/bin yet, tell the
  # operator how to. PATH is set in rc files we just edited, but those
  # only take effect on next shell start (or after `source`).
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) warn "~/.local/bin not yet in PATH for this shell. Run:" \
            && echo "      source ~/.bashrc    # or open a new terminal" \
            && echo "      then: $name --help" ;;
  esac
}

# personal_cmd_uninstall <name>
#   Remove the wrapper file. Idempotent (no error if already gone).
#   Does NOT touch the PATH line in rc files — call personal_cmd_clean_path
#   from uninstall.sh once the last instance is gone.
personal_cmd_uninstall() {
  local name="${1:?personal_cmd_uninstall: name required}"
  local target="$HOME/.local/bin/$name"
  if [[ -e "$target" || -L "$target" ]]; then
    rm -f "$target"
  fi
}

# personal_cmd_ensure_path
#   Add ~/.local/bin to PATH in ~/.bashrc and ~/.zshrc, if and only if
#   the marker line isn't already there. Idempotent: running twice
#   doesn't duplicate the entry. Files that don't exist are left alone
#   (some shells use neither bashrc nor zshrc — those operators fix
#   their PATH manually).
personal_cmd_ensure_path() {
  local rc
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -e "$rc" ]] || continue
    grep -Fq "$CLAUDIFY_PATH_MARKER" "$rc" && continue
    # Ensure file ends with a newline before appending so the marker
    # doesn't get mashed onto the last existing line.
    if [[ -s "$rc" ]] && [[ -n "$(tail -c1 "$rc")" ]]; then
      printf '\n' >> "$rc"
    fi
    printf '%s\n' "$CLAUDIFY_PATH_MARKER" >> "$rc"
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
  done
}

# personal_cmd_clean_path
#   Remove the marker line and the export line below it from rc files.
#   Called by uninstall.sh after the last instance is removed, per
#   CLAUDE.md rule 10 (no orphaned env state on full uninstall). Lines
#   not added by Claudify are untouched.
personal_cmd_clean_path() {
  local rc tmp
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -e "$rc" ]] || continue
    grep -Fq "$CLAUDIFY_PATH_MARKER" "$rc" || continue
    tmp="$(mktemp)"
    awk -v marker="$CLAUDIFY_PATH_MARKER" '
      $0 == marker          { skip = 1; next }
      skip == 1 && /^export PATH=.*\.local\/bin/ { skip = 0; next }
      skip == 1             { skip = 0 }
      { print }
    ' "$rc" > "$tmp"
    mv "$tmp" "$rc"
  done
}

# _personal_cmd_write_wrapper <name>
#   Emit the wrapper script to stdout. The OUTER heredoc (WRAPPER) is
#   unquoted so $name and ${CLAUDIFY_RAW_BASE} expand here at install
#   time; every other `$` is escaped so it's literal in the wrapper.
_personal_cmd_write_wrapper() {
  local name="$1"
  cat <<WRAPPER
#!/usr/bin/env bash
# Auto-generated by Claudify install for instance "$name".
# Edit at ~/.local/bin/$name only if you know what you're doing —
# this file gets regenerated on every Claudify install / update.

CLAUDIFY_INSTANCE="$name"

case "\${1:-}" in
  doctor)    exec bash <(curl -fsSL ${CLAUDIFY_RAW_BASE}/doctor.sh) --name "\$CLAUDIFY_INSTANCE" ;;
  update)    exec bash <(curl -fsSL ${CLAUDIFY_RAW_BASE}/update.sh) --name "\$CLAUDIFY_INSTANCE" ;;
  uninstall) exec bash <(curl -fsSL ${CLAUDIFY_RAW_BASE}/uninstall.sh) --name "\$CLAUDIFY_INSTANCE" "\${@:2}" ;;
  status)    systemctl --user status  "claudify-\$CLAUDIFY_INSTANCE" ;;
  logs)      journalctl --user -u     "claudify-\$CLAUDIFY_INSTANCE" -f ;;
  restart)   systemctl --user restart "claudify-\$CLAUDIFY_INSTANCE" ;;
  start)     systemctl --user start   "claudify-\$CLAUDIFY_INSTANCE" ;;
  stop)      systemctl --user stop    "claudify-\$CLAUDIFY_INSTANCE" ;;
  ""|help|-h|--help)
    cat <<HELP
\$CLAUDIFY_INSTANCE — your Claudify instance "\$CLAUDIFY_INSTANCE"

Usage:
  \$CLAUDIFY_INSTANCE doctor      Run health checks
  \$CLAUDIFY_INSTANCE update      Pull the latest Claudify and refresh in place
  \$CLAUDIFY_INSTANCE uninstall   Remove this instance entirely
  \$CLAUDIFY_INSTANCE status      Show systemd service status
  \$CLAUDIFY_INSTANCE logs        Follow service logs
  \$CLAUDIFY_INSTANCE restart     Restart the service
  \$CLAUDIFY_INSTANCE start       Start the service
  \$CLAUDIFY_INSTANCE stop        Stop the service
HELP
    ;;
  *)
    echo "Unknown subcommand: \$1" >&2
    "\$0" --help
    exit 2
    ;;
esac
WRAPPER
}
