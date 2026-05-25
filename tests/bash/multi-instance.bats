#!/usr/bin/env bats
#
# multi-instance.bats — verifies the flat layout + path resolution.
# Does NOT install real services (no systemctl available in CI). Tests
# the substrate: layout helpers + manifest path resolvers + validators.

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export SCRIPT_VERSION="0.1.0-test"

  # shellcheck disable=SC1090
  . "$REPO_ROOT/lib/layout.sh"
  # shellcheck disable=SC1090
  . "$REPO_ROOT/lib/validate.sh"
  # shellcheck disable=SC1090
  . "$REPO_ROOT/lib/manifest.sh"
}

teardown() {
  rm -rf "$TEST_HOME"
}

# ─── Layout ───────────────────────────────────────────────────────────────
@test "layout: default INSTANCE_NAME passes validate_instance_name (whoami or claudify-bot)" {
  # Post-3.4.6 (Claudify-e4a) fix: default is whoami when valid; falls back
  # to 'claudify-bot' for system accounts / uppercase / 'default'. Either
  # way the value must satisfy validate_instance_name.
  validate_instance_name "$INSTANCE_NAME"
}

@test "layout: paths follow the flat ~/.claudify-<name>/ pattern" {
  # Use the actual INSTANCE_NAME (whoami-based now) instead of hard-coding
  # 'default' — the structure of the paths is what we're checking.
  [[ "$CLAUDIFY_INSTANCE_DIR" == "$HOME/.claudify-${INSTANCE_NAME}" ]]
  [[ "$CLAUDIFY_WORKSPACE"    == "$HOME/.claudify-${INSTANCE_NAME}/workspace" ]]
  [[ "$CLAUDIFY_TELEGRAM"     == "$HOME/.claudify-${INSTANCE_NAME}/channels/telegram" ]]
  [[ "$CLAUDIFY_CLAUDE_DIR"   == "$HOME/.claudify-${INSTANCE_NAME}/claude" ]]
  [[ "$CREDS_FILE"            == "$HOME/.claudify-${INSTANCE_NAME}/credentials.env" ]]
  [[ "$CLAUDIFY_REGISTRY"     == "$HOME/.claudify-registry.json" ]]
}

@test "layout: claudify_init_layout picks up INSTANCE_NAME override" {
  INSTANCE_NAME="client-a"
  claudify_init_layout
  [[ "$CLAUDIFY_INSTANCE_DIR" == "$HOME/.claudify-client-a" ]]
  [[ "$CLAUDIFY_WORKSPACE"    == "$HOME/.claudify-client-a/workspace" ]]
  [[ "$CLAUDIFY_TELEGRAM"     == "$HOME/.claudify-client-a/channels/telegram" ]]
}

# ─── Validator ────────────────────────────────────────────────────────────
@test "validate_instance_name accepts good names" {
  # 'default' is intentionally NOT in this list — see the dedicated
  # rejection test below for the Claudify-e4a (OMZ collision) reason.
  validate_instance_name "client-a"
  validate_instance_name "business_2026"
  validate_instance_name "ab"
  validate_instance_name "david"
  validate_instance_name "claud"
}

@test "validate_instance_name rejects too-short / too-long / bad-format" {
  ! validate_instance_name "a"             # too short
  ! validate_instance_name "Default"       # uppercase
  ! validate_instance_name "1abc"          # starts with digit
  ! validate_instance_name "ab cd"         # space
  ! validate_instance_name "ab.cd"         # dot
  # 32 chars (1 + 31 = 32, max is 31)
  ! validate_instance_name "abcdefghijklmnopqrstuvwxyz012345"
}

@test "validate_instance_name rejects blocklisted names" {
  ! validate_instance_name "ls"
  ! validate_instance_name "rm"
  ! validate_instance_name "git"
  ! validate_instance_name "claude"
  ! validate_instance_name "claudify"
  ! validate_instance_name "docker"
  ! validate_instance_name "systemctl"
  ! validate_instance_name "sudo"
}

@test "validate_instance_name rejects 'default' (Claudify-e4a — OMZ collision)" {
  # Oh My Zsh defines a no-op default() function in ~/.oh-my-zsh/lib/functions.zsh
  # that silently shadows ~/.local/bin/default in interactive zsh. The blocklist
  # entry forces operators to pick a different name at install time.
  ! validate_instance_name "default"
}

# ─── Default instance name from whoami ────────────────────────────────────
@test "_claudify_default_instance_name returns whoami when it's a valid name" {
  # Stub id -un to a known-good name; whoami isn't reliable on macOS+bats.
  id() { echo "alice"; }
  export -f id
  result="$(_claudify_default_instance_name)"
  [[ "$result" == "alice" ]]
}

@test "_claudify_default_instance_name falls back when whoami is uppercase" {
  id() { echo "Alice"; }
  export -f id
  result="$(_claudify_default_instance_name)"
  [[ "$result" == "claudify-bot" ]]
}

@test "_claudify_default_instance_name falls back when whoami is literally 'default'" {
  id() { echo "default"; }
  export -f id
  result="$(_claudify_default_instance_name)"
  [[ "$result" == "claudify-bot" ]]
}

# ─── Manifest path resolvers ──────────────────────────────────────────────
@test "manifest: _registry_path is at \$HOME root, not nested" {
  result="$(_registry_path)"
  [[ "$result" == "$HOME/.claudify-registry.json" ]]
}

@test "manifest: _instance_manifest_path uses flat layout" {
  result="$(_instance_manifest_path "client-a")"
  [[ "$result" == "$HOME/.claudify-client-a/claudify.json" ]]
}

@test "manifest: registers two instances side by side" {
  INSTANCE_NAME="alpha"; claudify_init_layout
  manifest_register_instance alpha
  manifest_init_instance alpha

  INSTANCE_NAME="beta"; claudify_init_layout
  manifest_register_instance beta
  manifest_init_instance beta

  # Registry
  [[ -s "$HOME/.claudify-registry.json" ]]
  result="$(jq -r '.instances | keys | sort | join(",")' "$HOME/.claudify-registry.json")"
  [[ "$result" == "alpha,beta" ]]

  # Per-instance manifests
  [[ -s "$HOME/.claudify-alpha/claudify.json" ]]
  [[ -s "$HOME/.claudify-beta/claudify.json"  ]]

  # Service unit names are per-instance
  alpha_svc="$(jq -r '.instances.alpha.service' "$HOME/.claudify-registry.json")"
  beta_svc="$(jq -r '.instances.beta.service'  "$HOME/.claudify-registry.json")"
  [[ "$alpha_svc" == "claudify-alpha" ]]
  [[ "$beta_svc"  == "claudify-beta" ]]
}

@test "manifest: uninstalling one instance leaves the other" {
  manifest_register_instance alpha
  manifest_register_instance beta
  manifest_unregister_instance alpha

  result="$(jq -r '.instances | keys | join(",")' "$HOME/.claudify-registry.json")"
  [[ "$result" == "beta" ]]
}
