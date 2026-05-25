# lib/validate.sh — input format validators
#
# Pure functions: take a string, return 0 if valid, non-zero otherwise.
# No I/O, no side effects. Used by the *_validated prompt helpers.

validate_bot_token() { [[ "$1" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; }
validate_user_id()   { [[ "$1" =~ ^[0-9]+$ ]]; }
validate_workspace() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; }

# Instance name (3.4.5, refined 3.4.6 follow-up):
#   - regex: lowercase letter start, then 1-30 of [a-z0-9_-]; total 2-31 chars
#   - blocklist: common Unix command names + reserved words + the literal
#     'default' (an Oh My Zsh function ~/.oh-my-zsh/lib/functions.zsh defines
#     a no-op default() that shadows the wrapper at ~/.local/bin/default;
#     Claudify-e4a). Avoids accidental shell-name shadowing of the 3.4.6
#     personal command wrapper at ~/.local/bin/<name>.
validate_instance_name() {
  local name="$1"
  [[ "$name" =~ ^[a-z][a-z0-9_-]{1,30}$ ]] || return 1
  case "$name" in
    ls|cd|cp|mv|rm|cat|grep|find|git|npm|bun|node|claude|claudify) return 1 ;;
    docker|systemctl|journalctl|sudo|bash|sh|zsh|env|export|set)   return 1 ;;
    pwd|echo|test|true|false|kill|killall|ssh|scp|curl|wget)       return 1 ;;
    install|update|uninstall|doctor|backup|restore|build|help)     return 1 ;;
    default)                                                       return 1 ;;
  esac
  return 0
}
