#!/usr/bin/env bash
#
# gate.sh -- the single executable definition of "done". Everything else calls
# this. It takes no arguments except --fast, reads no config, and either passes
# or fails.
#
# EXIT CODES: 0 = pass, 2 = fail. NEVER 1. Claude Code treats exit 1 as a
# non-blocking error and proceeds anyway; exit 2 is what actually blocks.
#
# NO SIDE EFFECTS. This script never stages, commits, pushes, or writes any
# file. It produces an exit code and stderr, nothing else. CI runs this same
# script (T-009), and a gate that mutated git state would behave differently --
# or dangerously -- depending on who invoked it. Commit-and-push belongs to
# whoever calls the gate after it passes, never to the gate.
#
# PATHS: checks run against ${CLAUDE_PROJECT_DIR}, the consuming project's code.
# This script is LOCATED via ${CLAUDE_PLUGIN_ROOT} by whatever invokes it.
# Reversing those two fails silently. See ../hooks/hooks.json.
#
# Usage:  gate.sh           all six checks
#         gate.sh --fast    checks 1-3 only, for the per-edit hook
#
# Deliberately not `set -e`: exit codes are controlled explicitly, and -e would
# surface a failed check as exit 1, which does not block.
set -uo pipefail

# This script is bash, not POSIX sh: it uses BASH_SOURCE, arrays of behaviour
# via `local`, and [[-free but bash-specific idioms. Running it under dash or
# sh silently mis-resolves BASH_SOURCE and the gate would check the wrong
# directory. Fail loudly instead. On Windows, Git Bash is the supported shell
# (DESIGN.md §3, ADR-0006); gate.ps1 is the shim that finds it.
if [ -z "${BASH_VERSION:-}" ]; then
  printf 'GATE FAIL: this gate requires bash, but is running under a different shell.\n' >&2
  printf 'Run it as: bash %s\n' "$0" >&2
  printf 'On Windows, install Git for Windows (which provides Git Bash): https://git-scm.com/download/win\n' >&2
  exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -f "$HERE/lib.sh" ] || {
  printf 'GATE FAIL: %s/lib.sh is missing. The gate is incomplete; do not proceed.\n' "$HERE" >&2
  exit 2
}
# shellcheck source=lib.sh
. "$HERE/lib.sh"

FAST=0
case "${1:-}" in
  "")     ;;
  --fast) FAST=1 ;;
  *)      printf 'GATE FAIL: unknown argument "%s". Use --fast or no argument.\n' "$1" >&2; exit 2 ;;
esac

run_check() {
  local f="$HERE/check-$1.sh"
  CHECK="$1"   # set before sourcing so a missing file is not reported under the previous check's name
  # A check that cannot run is a failed check -- including a missing one.
  [ -f "$f" ] || die "check file $f is missing. The gate is incomplete; restore it rather than skipping."
  # shellcheck source=/dev/null
  . "$f"
}

# Order is fixed: cheapest first, and 1-3 are exactly what --fast runs.
run_check 01-build
run_check 02-tests
run_check 03-lint

if [ "$FAST" = 1 ]; then
  note "--fast: checks 4-6 (working memory, task ledger, spec gaps) not run."
  exit 0
fi

run_check 04-working-memory
run_check 05-task-ledger
run_check 06-spec-gaps

note "all checks passed."
exit 0
