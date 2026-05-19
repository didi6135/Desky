#!/usr/bin/env bats
#
# personal-cmd.bats — covers ~/.local/bin/<name> wrapper generation,
# wrapper --help output, PATH idempotency in rc files, uninstall
# removal, and rc-file PATH cleanup. No real systemctl needed.

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

  # ok_done / warn are defined in ui.sh and used by personal_cmd_install
  # for non-fatal status output — sourcing it keeps the tests realistic.
  # shellcheck disable=SC1090
  . "$REPO_ROOT/lib/ui.sh"
  # shellcheck disable=SC1090
  . "$REPO_ROOT/lib/personal-cmd.sh"
}

teardown() {
  rm -rf "$TEST_HOME"
}

# ─── Wrapper generation ───────────────────────────────────────────────────
@test "personal_cmd_install creates an executable at ~/.local/bin/<name>" {
  personal_cmd_install "test-x"
  [[ -x "$HOME/.local/bin/test-x" ]]
}

@test "wrapper contains a CLAUDIFY_INSTANCE line bound to the right name" {
  personal_cmd_install "test-x"
  grep -q '^CLAUDIFY_INSTANCE="test-x"$' "$HOME/.local/bin/test-x"
}

@test "wrapper --help output mentions the instance name" {
  personal_cmd_install "test-x"
  result="$("$HOME/.local/bin/test-x" --help)"
  [[ "$result" == *"test-x"* ]]
  [[ "$result" == *"doctor"* ]]
  [[ "$result" == *"status"* ]]
  [[ "$result" == *"logs"* ]]
}

@test "wrapper with no args prints help (same as --help)" {
  personal_cmd_install "test-x"
  result_no_arg="$("$HOME/.local/bin/test-x")"
  result_help="$("$HOME/.local/bin/test-x" --help)"
  [[ "$result_no_arg" == "$result_help" ]]
}

@test "wrapper rejects unknown subcommand with exit 2" {
  personal_cmd_install "test-x"
  run "$HOME/.local/bin/test-x" totally-bogus
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"Unknown subcommand: totally-bogus"* ]]
}

@test "re-running personal_cmd_install regenerates wrapper cleanly" {
  personal_cmd_install "test-x"
  # Mutate the file, then re-install — the regen must restore canonical contents.
  echo "# tampered" >> "$HOME/.local/bin/test-x"
  personal_cmd_install "test-x"
  ! grep -q "# tampered" "$HOME/.local/bin/test-x"
}

# ─── PATH update (rc files) ───────────────────────────────────────────────
@test "personal_cmd_ensure_path appends the marker + export to .bashrc" {
  touch "$HOME/.bashrc"
  personal_cmd_ensure_path
  grep -Fq "# Claudify PATH —" "$HOME/.bashrc"
  grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"
}

@test "personal_cmd_ensure_path is idempotent (running twice doesn't duplicate)" {
  touch "$HOME/.bashrc"
  personal_cmd_ensure_path
  personal_cmd_ensure_path
  count="$(grep -Fc "# Claudify PATH —" "$HOME/.bashrc")"
  [[ "$count" == "1" ]]
}

@test "personal_cmd_ensure_path updates both .bashrc and .zshrc when present" {
  touch "$HOME/.bashrc" "$HOME/.zshrc"
  personal_cmd_ensure_path
  grep -Fq "# Claudify PATH —" "$HOME/.bashrc"
  grep -Fq "# Claudify PATH —" "$HOME/.zshrc"
}

@test "personal_cmd_ensure_path skips files that don't exist (no .zshrc created)" {
  touch "$HOME/.bashrc"
  personal_cmd_ensure_path
  [[ -f "$HOME/.bashrc" ]]
  [[ ! -e "$HOME/.zshrc" ]]
}

@test "personal_cmd_ensure_path preserves an rc file with no trailing newline" {
  printf 'echo hi' > "$HOME/.bashrc"   # no trailing \n
  personal_cmd_ensure_path
  grep -q '^echo hi$' "$HOME/.bashrc"
  grep -Fq "# Claudify PATH —" "$HOME/.bashrc"
}

# ─── Uninstall ────────────────────────────────────────────────────────────
@test "personal_cmd_uninstall removes the wrapper file" {
  personal_cmd_install "test-x"
  personal_cmd_uninstall "test-x"
  [[ ! -e "$HOME/.local/bin/test-x" ]]
}

@test "personal_cmd_uninstall is idempotent when the wrapper is already gone" {
  personal_cmd_uninstall "never-installed"
  [[ ! -e "$HOME/.local/bin/never-installed" ]]
}

# ─── PATH cleanup (full uninstall) ────────────────────────────────────────
@test "personal_cmd_clean_path removes marker + export, leaves other lines" {
  cat > "$HOME/.bashrc" <<'RC'
# user line above
alias ll='ls -la'
# Claudify PATH —
export PATH="$HOME/.local/bin:$PATH"
# user line below
alias gs='git status'
RC
  personal_cmd_clean_path
  ! grep -Fq "# Claudify PATH —" "$HOME/.bashrc"
  ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"
  grep -q "^alias ll=" "$HOME/.bashrc"
  grep -q "^alias gs=" "$HOME/.bashrc"
}

@test "personal_cmd_clean_path is a no-op on rc files without the marker" {
  printf 'alias ll=ls\n' > "$HOME/.bashrc"
  personal_cmd_clean_path
  grep -q "^alias ll=ls$" "$HOME/.bashrc"
}
