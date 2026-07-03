#!/usr/bin/env bash
# Mechanical wrapper for the codex-delegate state and execution protocol.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  delegate.sh init <mode> <topic> [--force]
  delegate.sh exec <mode> <topic> [--force] [--resume|--fresh]
  delegate.sh append [--round N] <mode> <topic> <status> <notes...>
  delegate.sh status

modes: implement | explore | test | decide
topics: ^[a-z0-9][a-z0-9._-]*$
EOF
  exit 2
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

warn() {
  echo "WARN: $*" >&2
}

is_mode() {
  case "$1" in
    implement|explore|test|decide) return 0 ;;
    *) return 1 ;;
  esac
}

is_topic() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]
}

is_positive_int() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

init_paths() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repo"
  BRANCH="$(git branch --show-current 2>/dev/null)"
  [ -n "$BRANCH" ] || die "detached HEAD is not supported"

  BRANCH_KEY="$(printf "%s" "$BRANCH" | tr '/:' '__' | tr -c 'A-Za-z0-9._-' '_')"
  STATE_DIR="$HOME/.claude/codex-work/$(basename "$REPO_ROOT")-${BRANCH_KEY}"
  STATE_FILE="$STATE_DIR/state.json"

  if [ "${CODEX_BIN+x}" = x ] && [ -n "${CODEX_BIN:-}" ]; then
    CODEX_BIN_OVERRIDDEN=1
  else
    CODEX_BIN_OVERRIDDEN=0
  fi
  CODEX_BIN="${CODEX_BIN:-codex}"
}

create_state_if_missing() {
  if [ -f "$STATE_FILE" ]; then
    return 0
  fi

  local tmp
  tmp="$(mktemp "$STATE_FILE.tmp.XXXXXX")"
  if jq -n --arg repo "$REPO_ROOT" --arg branch "$BRANCH" \
    '{repo: $repo, branch: $branch, thread_id: "", open_round: null, history: []}' > "$tmp"; then
    mv "$tmp" "$STATE_FILE"
  else
    rm -f "$tmp"
    return 1
  fi
}

require_state() {
  [ -f "$STATE_FILE" ] || die "run init first"
}

atomic_jq_state() {
  local tmp
  tmp="$(mktemp "$STATE_FILE.tmp.XXXXXX")"
  if jq "$@" "$STATE_FILE" > "$tmp"; then
    mv "$tmp" "$STATE_FILE"
  else
    rm -f "$tmp"
    return 1
  fi
}

open_round_json() {
  jq -c '.open_round // empty' "$STATE_FILE"
}

refuse_open_round_unless_forced() {
  local force="$1"
  local open_round
  open_round="$(open_round_json)"
  if [ -n "$open_round" ] && [ "$force" != "1" ]; then
    echo "$open_round" >&2
    die "adjudicate with append first"
  fi
}

version_lt_0_140() {
  local version="$1"
  local major minor rest

  major="${version%%.*}"
  rest="${version#*.}"
  if [ "$rest" = "$version" ]; then
    minor=0
  else
    minor="${rest%%.*}"
  fi

  case "$major:$minor" in
    *[!0-9:]*|:*) return 1 ;;
  esac

  [ "$major" -eq 0 ] && [ "$minor" -lt 140 ]
}

preflight() {
  if ! command -v "$CODEX_BIN" >/dev/null 2>&1; then
    if [ "$CODEX_BIN_OVERRIDDEN" = "1" ]; then
      warn "CODEX_BIN not found: $CODEX_BIN"
    else
      die "missing codex binary (set CODEX_BIN to override)"
    fi
  else
    local version_output version
    version_output="$("$CODEX_BIN" --version 2>/dev/null || true)"
    version="$(printf "%s\n" "$version_output" | grep -Eo '[0-9]+([.][0-9]+){1,2}' | head -1 || true)"
    if [ -z "$version" ]; then
      warn "codex --version unavailable"
    elif version_lt_0_140 "$version"; then
      warn "codex --version $version is below 0.140"
    fi
  fi

  if [ ! -f "$HOME/.codex/config.toml" ]; then
    warn "missing ~/.codex/config.toml model/model_reasoning_effort"
  else
    grep -E '^[[:space:]]*model[[:space:]]*=' "$HOME/.codex/config.toml" >/dev/null 2>&1 ||
      warn "missing model in ~/.codex/config.toml"
    grep -E '^[[:space:]]*model_reasoning_effort[[:space:]]*=' "$HOME/.codex/config.toml" >/dev/null 2>&1 ||
      warn "missing model_reasoning_effort in ~/.codex/config.toml"
  fi

  if [ -f "$REPO_ROOT/package.json" ] &&
    ! grep '"packageManager"' "$REPO_ROOT/package.json" >/dev/null 2>&1; then
    warn "PM UNPINNED — name the package-manager major in the brief's Rules"
  fi
}

snapshot_baseline() {
  local topic="$1"
  local status_file="$STATE_DIR/baseline-$topic.status"
  local patch_file="$STATE_DIR/baseline-$topic.patch"

  git -C "$REPO_ROOT" status --porcelain > "$status_file"
  if [ -s "$status_file" ]; then
    git -C "$REPO_ROOT" diff HEAD > "$patch_file"
  else
    rm -f "$patch_file"
  fi
}

cmd_init() {
  local mode="$1"
  local topic="$2"
  local force="$3"

  mkdir -p "$STATE_DIR"
  create_state_if_missing
  refuse_open_round_unless_forced "$force"
  snapshot_baseline "$topic"
  preflight

  echo "STATE_DIR=$STATE_DIR"
  echo "BRIEF=$STATE_DIR/brief-$mode-$topic.md"
}

next_round() {
  local mode="$1"
  local topic="$2"
  local path name idx highest

  highest=0
  for path in "$STATE_DIR/exec-$mode-$topic-"*.jsonl; do
    [ -e "$path" ] || continue
    name="${path##*/}"
    idx="${name#exec-$mode-$topic-}"
    idx="${idx%.jsonl}"
    case "$idx" in
      ''|*[!0-9]*) continue ;;
    esac
    if [ "$idx" -gt "$highest" ]; then
      highest="$idx"
    fi
  done

  echo $((highest + 1))
}

read_stdin_prompt() {
  PROMPT=""
  IFS= read -r -d '' PROMPT || true
  [ -n "$PROMPT" ] || die "stdin prompt is empty"
}

capture_thread_id() {
  local jsonl="$1"
  local line

  line="$(grep -m 1 '"thread_id"' "$jsonl" || true)"
  if [ -z "$line" ]; then
    echo ""
    return 0
  fi
  printf "%s\n" "$line" | jq -r '.thread_id // empty' 2>/dev/null || true
}

set_open_round() {
  local mode="$1"
  local topic="$2"
  local round="$3"

  atomic_jq_state --arg mode "$mode" --arg topic "$topic" --argjson round "$round" \
    '.open_round = {mode: $mode, topic: $topic, round: $round}'
}

cmd_exec() {
  local mode="$1"
  local topic="$2"
  local force="$3"
  local thread_control="$4"
  local brief schema_file last_message jsonl round thread_id status rc resume last_history_status
  local -a cmd

  require_state
  brief="$STATE_DIR/brief-$mode-$topic.md"
  [ -f "$brief" ] || die "missing brief: $brief"
  schema_file="$SKILL_DIR/schemas/$mode.json"
  [ -f "$schema_file" ] || die "missing schema: $schema_file"
  if [ "$mode" = "decide" ] && [ "$thread_control" = "resume" ]; then
    die "decide mode never resumes"
  fi
  if [ "$mode" != "decide" ] && [ "$thread_control" = "auto" ]; then
    last_history_status="$(jq -r --arg mode "$mode" --arg topic "$topic" \
      '([.history[] | select(.mode == $mode and .topic == $topic)] | last | .status) // ""' "$STATE_FILE")"
    case "$last_history_status" in
      aborted|rejected)
        die "last $mode/$topic round was $last_history_status; pass --resume or --fresh explicitly"
        ;;
    esac
  fi
  read_stdin_prompt
  refuse_open_round_unless_forced "$force"

  round="$(next_round "$mode" "$topic")"
  last_message="$STATE_DIR/last-message-$topic.json"
  jsonl="$STATE_DIR/exec-$mode-$topic-$round.jsonl"
  : > "$last_message"

  resume=0
  if [ "$mode" != "decide" ]; then
    case "$thread_control" in
      resume)
        resume=1
        ;;
      fresh)
        resume=0
        ;;
      auto)
        if [ "$round" -gt 1 ]; then
          resume=1
        fi
        ;;
    esac
  fi

  if [ "$resume" = "1" ]; then
    thread_id="$(jq -r '.thread_id // ""' "$STATE_FILE")"
    [ -n "$thread_id" ] || die "missing thread_id for resume"
    cmd=("$CODEX_BIN" exec resume "$thread_id" --json -o "$last_message" --dangerously-bypass-approvals-and-sandbox --output-schema "$schema_file" "$PROMPT")
  else
    cmd=("$CODEX_BIN" exec --json -o "$last_message" --dangerously-bypass-approvals-and-sandbox --output-schema "$schema_file" "$PROMPT")
  fi

  set +e
  (cd "$REPO_ROOT" && "${cmd[@]}") > "$jsonl" 2>&1
  rc=$?
  set -e

  thread_id="$(capture_thread_id "$jsonl")"
  if [ -n "$thread_id" ]; then
    atomic_jq_state --arg thread_id "$thread_id" '.thread_id = $thread_id'
  fi

  if [ "$rc" -ne 0 ] ||
    [ -z "$thread_id" ] ||
    ! jq -e '.status | strings | select(length > 0)' "$last_message" >/dev/null 2>&1; then
    set_open_round "$mode" "$topic" "$round"
    echo "jsonl: $jsonl" >&2
    exit 1
  fi

  set_open_round "$mode" "$topic" "$round"

  status="$(jq -r '.status' "$last_message")"
  echo "round=$round"
  echo "thread_id=$thread_id"
  echo "status=$status"
  echo "last_message=$last_message"
}

cmd_append() {
  local round_arg="$1"
  local mode="$2"
  local topic="$3"
  local status="$4"
  shift 4

  local notes open_round round clear_open
  notes="$*"
  [ -n "$notes" ] || die "notes must be non-empty"

  require_state

  open_round="$(jq -r --arg mode "$mode" --arg topic "$topic" \
    'if .open_round != null and .open_round.mode == $mode and .open_round.topic == $topic then .open_round.round else empty end' "$STATE_FILE")"

  if [ -n "$open_round" ]; then
    round="$open_round"
    clear_open=true
  else
    [ -n "$round_arg" ] || die "no matching open_round; pass --round N"
    round="$round_arg"
    clear_open=false
  fi

  atomic_jq_state \
    --arg mode "$mode" \
    --arg topic "$topic" \
    --arg status "$status" \
    --arg notes "$notes" \
    --argjson round "$round" \
    --argjson clear_open "$clear_open" \
    '.history += [{mode: $mode, topic: $topic, round: $round, status: $status, notes: $notes}]
      | if $clear_open then .open_round = null else . end'

  jq -c '.history[-1]' "$STATE_FILE"
}

cmd_status() {
  local pattern path size

  require_state
  jq . "$STATE_FILE"

  for pattern in brief-* exec-* last-message-* baseline-*; do
    for path in "$STATE_DIR"/$pattern; do
      [ -e "$path" ] || continue
      size="$(wc -c < "$path" | tr -d '[:space:]')"
      printf "%s %s\n" "$size" "${path##*/}"
    done
  done
}

parse_force_tail() {
  if [ "$#" -eq 2 ]; then
    echo "0"
  elif [ "$#" -eq 3 ] && [ "$3" = "--force" ]; then
    echo "1"
  else
    usage
  fi
}

main() {
  local subcommand mode topic force round_arg status thread_control want_resume want_fresh

  [ "$#" -gt 0 ] || usage
  subcommand="$1"
  shift

  case "$subcommand" in
    init)
      force="$(parse_force_tail "$@")"
      mode="$1"
      topic="$2"
      is_mode "$mode" || usage
      is_topic "$topic" || usage
      init_paths
      cmd_init "$mode" "$topic" "$force"
      ;;
    exec)
      [ "$#" -ge 2 ] || usage
      mode="$1"
      topic="$2"
      shift 2
      is_mode "$mode" || usage
      is_topic "$topic" || usage
      force=0
      want_resume=0
      want_fresh=0
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --force)
            force=1
            ;;
          --resume)
            want_resume=1
            ;;
          --fresh)
            want_fresh=1
            ;;
          *)
            usage
            ;;
        esac
        shift
      done
      if [ "$want_resume" = "1" ] && [ "$want_fresh" = "1" ]; then
        usage
      fi
      thread_control=auto
      if [ "$want_resume" = "1" ]; then
        thread_control=resume
      elif [ "$want_fresh" = "1" ]; then
        thread_control=fresh
      fi
      init_paths
      cmd_exec "$mode" "$topic" "$force" "$thread_control"
      ;;
    append)
      round_arg=""
      if [ "$#" -ge 2 ] && [ "$1" = "--round" ]; then
        round_arg="$2"
        is_positive_int "$round_arg" || usage
        shift 2
      fi
      [ "$#" -ge 4 ] || usage
      mode="$1"
      topic="$2"
      status="$3"
      shift 3
      is_mode "$mode" || usage
      is_topic "$topic" || usage
      case "$status" in
        approved|corrected|rejected|aborted) ;;
        *) usage ;;
      esac
      init_paths
      cmd_append "$round_arg" "$mode" "$topic" "$status" "$@"
      ;;
    status)
      [ "$#" -eq 0 ] || usage
      init_paths
      cmd_status
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
