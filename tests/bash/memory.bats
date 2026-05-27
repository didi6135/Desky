#!/usr/bin/env bats
#
# memory.bats — covers lib/memory.sh + the new manifest.sh skill helpers
# (manifest_set_skill, manifest_get_skill_memory). Each test runs in a
# fresh temp HOME so it doesn't touch the dev machine's real
# ~/.desky-default/.

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export SCRIPT_VERSION="0.1.0-test"
  export DESKY_ENGINE="claude-code"

  # shellcheck disable=SC1090
  . "$REPO_ROOT/lib/layout.sh"
  # shellcheck disable=SC1090
  . "$REPO_ROOT/lib/manifest.sh"
  # shellcheck disable=SC1090
  . "$REPO_ROOT/lib/memory.sh"
}

teardown() {
  rm -rf "$TEST_HOME"
}

# ─── memory_dir ───────────────────────────────────────────────────────────
@test "memory_dir creates the dir under instance data root" {
  result="$(memory_dir reminders)"
  [[ "$result" == "$DESKY_INSTANCE_DIR/data/reminders" ]]
  [[ -d "$result" ]]
}

@test "memory_dir applies mode 700" {
  result="$(memory_dir reminders)"
  if stat -c '%a' "$result" >/dev/null 2>&1; then
    perms="$(stat -c '%a' "$result")"
    [[ "$perms" == "700" ]]
  else
    skip "stat -c not available on this platform"
  fi
}

@test "memory_dir is idempotent (call twice = same path, no errors)" {
  first="$(memory_dir reminders)"
  second="$(memory_dir reminders)"
  [[ "$first" == "$second" ]]
  [[ -d "$first" ]]
}

# ─── memory_path ──────────────────────────────────────────────────────────
@test "memory_path returns <data-dir>/<filename>" {
  result="$(memory_path reminders r.db)"
  [[ "$result" == "$DESKY_INSTANCE_DIR/data/reminders/r.db" ]]
}

# ─── memory_export_env ────────────────────────────────────────────────────
@test "memory_export_env sets DESKY_SKILL_DATA to the skill's data dir" {
  memory_export_env reminders
  [[ "$DESKY_SKILL_DATA" == "$DESKY_INSTANCE_DIR/data/reminders" ]]
  [[ -d "$DESKY_SKILL_DATA" ]]
}

# ─── manifest_set_skill + manifest_get_skill_memory ───────────────────────
@test "manifest_set_skill with no memory args creates a bare entry" {
  manifest_set_skill default reminders
  result="$(jq -r '.skills | length' "$DESKY_INSTANCE_DIR/desky.json")"
  [[ "$result" == "1" ]]
  result="$(jq -r '.skills[0].id' "$DESKY_INSTANCE_DIR/desky.json")"
  [[ "$result" == "reminders" ]]
  # No memory key when neither slot was given
  result="$(jq -r '.skills[0] | has("memory")' "$DESKY_INSTANCE_DIR/desky.json")"
  [[ "$result" == "false" ]]
}

@test "manifest_set_skill is idempotent on id (one entry per id)" {
  manifest_set_skill default reminders
  manifest_set_skill default reminders '"reminders.db"'
  result="$(jq -r '.skills | length' "$DESKY_INSTANCE_DIR/desky.json")"
  [[ "$result" == "1" ]]
  result="$(jq -r '.skills[0].memory.writes' "$DESKY_INSTANCE_DIR/desky.json")"
  [[ "$result" == "reminders.db" ]]
}

@test "manifest_get_skill_memory returns empty when skill is missing" {
  manifest_init_instance default
  result="$(manifest_get_skill_memory default missing)"
  [[ -z "$result" ]]
}

@test "manifest_get_skill_memory returns compact JSON when present" {
  manifest_set_skill default reminders '"reminders.db"' '["persona.db"]'
  result="$(manifest_get_skill_memory default reminders)"
  [[ "$result" == '{"writes":"reminders.db","reads":["persona.db"]}' ]]
}

# ─── memory_assert_write ──────────────────────────────────────────────────
@test "memory_assert_write passes when manifest declares the db (string form)" {
  manifest_set_skill default reminders '"reminders.db"'
  memory_assert_write reminders reminders.db
}

@test "memory_assert_write passes for every name in the writes array" {
  manifest_set_skill default reminders '["r.db","backup.db"]'
  memory_assert_write reminders r.db
  memory_assert_write reminders backup.db
}

@test "memory_assert_write fails when skill has no memory declaration" {
  manifest_set_skill default reminders
  ! memory_assert_write reminders reminders.db
}

@test "memory_assert_write fails when db name not in writes" {
  manifest_set_skill default reminders '"reminders.db"'
  ! memory_assert_write reminders other.db
}

# ─── memory_assert_read ───────────────────────────────────────────────────
@test "memory_assert_read passes when manifest reads lists the db" {
  manifest_set_skill default reminders '"reminders.db"' '["persona.db"]'
  memory_assert_read reminders persona.db
}

@test "memory_assert_read fails when db name not in reads" {
  manifest_set_skill default reminders '"reminders.db"' '["persona.db"]'
  ! memory_assert_read reminders other.db
}
