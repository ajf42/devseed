#!/usr/bin/env bash
#
# gate-regression.sh -- the scratch-project procedure, executable.
#
# Builds a throwaway Python project with a real test suite and asserts the
# gate's behaviour against it. devseed itself has no build, tests, or linter
# (DESIGN.md §3), so checks 1-3 pass vacuously here and can only be exercised
# against a project that actually declares tooling.
#
# devseed's own dev tooling. Not shipped in the plugin.
#
# Usage: bash scripts/gate-regression.sh    (exit 0 = all assertions passed)
set -uo pipefail

GATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/plugins/governed-dev/gates/gate.sh"
WORK="${TMPDIR:-/tmp}/devseed-gate-regression.$$"
PASS=0; FAIL=0

trap 'rm -rf "$WORK"' EXIT

ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
# run_gate <expected-exit> <description> [args...]
run_gate() {
  local want="$1" desc="$2"; shift 2
  local got; ( cd "$WORK" && bash "$GATE" "$@" ) >/dev/null 2>&1; got=$?
  if [ "$got" = "$want" ]; then ok "$desc (exit $got)"; else bad "$desc -- wanted exit $want, got $got"; fi
  [ "$got" != 1 ] || bad "$desc RETURNED 1 -- exit 1 does not block and must never be returned"
}

scaffold() {
  rm -rf "$WORK"; mkdir -p "$WORK/src" "$WORK/tests"; cd "$WORK" || exit 2
  git init -q .; git config user.email regression@local; git config user.name regression
  printf 'def add(a, b):\n    return a + b\n' > src/m.py
  printf 'import sys, os\nsys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))\nfrom m import add\n\n\ndef test_add():\n    assert add(1, 2) == 3\n' > tests/test_m.py
  printf '# CLAUDE.md\n' > CLAUDE.md
  printf '# TASKS.md\n' > TASKS.md
  printf '# DECISIONS.md\n\n## Spec gaps observed\n' > DECISIONS.md
  git add -A >/dev/null 2>&1; git commit -qm init
}

echo "gate regression: $GATE"
scaffold

# --- Item 1 regression -------------------------------------------------------
# The gate runs pytest (check 2), which writes __pycache__ into the tree that
# check 4 then inspects. Before ADR-0005 this made the gate fail itself on a
# committed tree -- and keep failing. A gate that passes once and fails on
# re-run is the worst failure mode: it trains the reader to ignore it.
echo "item 1 -- gate must not poison itself:"
run_gate 0 "run 1 on a committed tree"
run_gate 0 "run 2 on the same tree (no changes between runs)"
run_gate 0 "run 3, --fast" --fast

echo
echo "summary: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ] || exit 2
exit 0
