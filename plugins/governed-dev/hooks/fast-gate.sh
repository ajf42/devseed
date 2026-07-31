#!/usr/bin/env bash
#
# fast-gate.sh -- PostToolUse on Edit|Write. Runs `gate.sh --fast` (checks 1-3:
# build, tests, lint) against the project so a broken build surfaces at the edit
# that broke it rather than at the end of the turn, several edits later, with
# the cause buried.
#
# Wired with "asyncRewake": true, NOT "async": true. Both run in the background;
# only asyncRewake wakes Claude when the script exits 2 and shows it the stderr.
# Under plain async the failure would be computed and then discarded, which is
# the silent degradation this hook exists to prevent. See hooks.json.
#
# Exit 2 does not block anything at PostToolUse -- the tool already ran. It is
# the signal asyncRewake watches for.
HOOK_NAME="PostToolUse/fast-gate"
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

have_jq || { hook_jq_advice >&2; hook_die "cannot read the edited path without jq."; }

FILE="$(hook_field '.tool_input.file_path // .tool_input.notebook_path')"
REL="$(printf '%s' "$FILE" | tr '\\' '/')"

# Source files only. Checks 1-3 run the project's build, tests and linter, none
# of which a documentation edit can affect -- running them on every CLAUDE.md
# save would spend a test suite per keystroke and train the reader to ignore the
# result. Scoped here in the script rather than via hooks.json's `if` field so
# the rule is one readable list instead of one permission-rule string per
# extension.
case "$REL" in
  */src/*|src/*) ;;
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.py|*.go|*.rs|*.rb|*.java|*.kt|*.swift) ;;
  *.c|*.h|*.cc|*.cpp|*.hpp|*.cs|*.php|*.sh|*.bash|*.ps1|*.sql) ;;
  *) exit 0 ;;
esac

GATE="$(hook_gate)"
[ -f "$GATE" ] || {
  printf 'The gate is missing at %s, so nothing verified this edit.\n' "$GATE" >&2
  printf 'A check that cannot run is a failed check. Restore the gate rather than proceeding.\n' >&2
  exit 2
}

ROOT="$(hook_root)"
ERR="$(CLAUDE_PROJECT_DIR="$ROOT" bash "$GATE" --fast 2>&1 >/dev/null)"
RC=$?

[ "$RC" = 0 ] && exit 0

{ printf 'Fast gate failed after editing %s:\n\n%s\n\n' "${REL:-a file}" "$ERR"
  printf 'These are checks 1-3 (build, tests, lint). Fix this before continuing --\n'
  printf 'the full gate runs at the end of the turn and will block on it anyway.\n'
} >&2
exit 2
