# lib/memory.sh — per-skill data dirs + ${CLAUDIFY_SKILL_DATA}
#
# Skill storage substrate, ahead of any actual skill. Two responsibilities:
#
# 1. Resolve a per-skill, mode-700 data directory under
#    ${CLAUDIFY_INSTANCE_DIR}/data/<skill-id>/. Different skill, different
#    path — file-level isolation, no broker, no daemon. Matches Anthropic's
#    ${CLAUDE_PLUGIN_DATA} convention so cross-ecosystem skills work.
#
# 2. Manifest-driven *accident* asserts (memory.writes / memory.reads).
#    Per ADR 0006 the trust model is single-user; the asserts catch
#    typos in db names, not adversaries.
#
# Storage substrate persists across update.sh and --reset-config; only
# uninstall.sh wipes ${CLAUDIFY_INSTANCE_DIR}.
#
# Layout constants come from lib/layout.sh (CLAUDIFY_INSTANCE_DIR,
# INSTANCE_NAME). Manifest helpers come from lib/manifest.sh
# (manifest_get_skill_memory). No engine coupling.
#
# Exposes:
#   memory_dir <skill-id>                  — echo + mkdir 700 the skill's data dir
#   memory_path <skill-id> <filename>      — echo "<memory_dir>/<filename>"
#   memory_assert_write <skill-id> <db>    — non-zero if memory.writes lacks <db>
#   memory_assert_read  <skill-id> <db>    — non-zero if memory.reads  lacks <db>
#   memory_export_env <skill-id>           — export CLAUDIFY_SKILL_DATA=<memory_dir>

_memory_root() {
  printf '%s/data' "$CLAUDIFY_INSTANCE_DIR"
}

memory_dir() {
  local skill_id="${1:?memory_dir: skill-id required}"
  local d
  d="$(_memory_root)/$skill_id"
  mkdir -p "$d"
  chmod 700 "$d"
  printf '%s' "$d"
}

memory_path() {
  local skill_id="${1:?memory_path: skill-id required}"
  local filename="${2:?memory_path: filename required}"
  printf '%s/%s' "$(memory_dir "$skill_id")" "$filename"
}

# Manifest-driven assert: was <db> declared under the named slot?
# slot ∈ {writes, reads}. Both string and array JSON forms accepted.
_memory_assert() {
  local skill_id="$1" db_name="$2" slot="$3"
  local instance="${INSTANCE_NAME:-default}"
  local mem allowed
  mem="$(manifest_get_skill_memory "$instance" "$skill_id" 2>/dev/null || true)"
  if [[ -z "$mem" || "$mem" == "null" ]]; then
    printf 'memory: skill %q has no memory declaration — refusing %s of %q\n' \
           "$skill_id" "$slot" "$db_name" >&2
    return 1
  fi
  allowed="$(printf '%s' "$mem" | jq -r --arg slot "$slot" '
    (.[$slot] // empty) | if type == "array" then .[] else . end
  ')"
  if ! printf '%s\n' "$allowed" | grep -Fxq -- "$db_name"; then
    printf 'memory: skill %q tried to %s %q but manifest allows only: %s\n' \
           "$skill_id" "$slot" "$db_name" \
           "$(printf '%s' "$allowed" | tr '\n' ' ')" >&2
    return 1
  fi
}

memory_assert_write() {
  _memory_assert "${1:?memory_assert_write: skill-id required}" \
                 "${2:?memory_assert_write: db-name required}" \
                 writes
}

memory_assert_read() {
  _memory_assert "${1:?memory_assert_read: skill-id required}" \
                 "${2:?memory_assert_read: db-name required}" \
                 reads
}

memory_export_env() {
  local skill_id="${1:?memory_export_env: skill-id required}"
  CLAUDIFY_SKILL_DATA="$(memory_dir "$skill_id")"
  export CLAUDIFY_SKILL_DATA
}
