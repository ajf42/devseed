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


# --- Item 4 regression -------------------------------------------------------
# Check 5 originally matched hash *shape*. A fabricated but well-formed hash
# passed, so the ledger could claim work no commit ever did.
echo
echo "item 4 -- check 5 must verify the hash resolves, not just its shape:"
printf '\n## T-001 — real\n\n- **Status:** done\n- **Commit:** `%s`\n' \
  "$( cd "$WORK" && git rev-parse --short=8 HEAD )" >> "$WORK/TASKS.md"
( cd "$WORK" && git add -A >/dev/null 2>&1 && git commit -qm "ledger" )
run_gate 0 "real commit hash accepted"

printf '\n## T-002 — fabricated\n\n- **Status:** done\n- **Commit:** `deadbee`\n' >> "$WORK/TASKS.md"
run_gate 2 "fabricated hash 'deadbee' rejected"

# And a done task with no hash at all.
scaffold
printf '\n## T-003 — hashless\n\n- **Status:** done\n- **Commit:** —\n' >> "$WORK/TASKS.md"
run_gate 2 "done task with no hash rejected"


# --- T-006 regression: the drift guard ---------------------------------------
# Check 7 reads the ledger documents, so it needs a project that HAS them --
# the bare scaffold above deliberately does not. Each case below starts from a
# clean, passing set and introduces exactly one defect, because a guard is only
# proved by what it rejects: one that passes everything and one that fails
# everything are indistinguishable from a clean run.
DRIFT="$(dirname "$GATE")/drift.sh"

# run_drift <expected-exit> <description> [must-appear-in-output]
run_drift() {
  local want="$1" desc="$2" needle="${3:-}" out got
  out="$( cd "$WORK" && bash "$DRIFT" 2>&1 )"; got=$?
  if [ "$got" = "$want" ]; then ok "$desc (exit $got)"; else bad "$desc -- wanted exit $want, got $got"; fi
  [ "$got" != 1 ] || bad "$desc RETURNED 1 -- exit 1 does not block and must never be returned"
  if [ -n "$needle" ]; then
    case "$out" in
      *"$needle"*) ok "$desc -- names '$needle'" ;;
      *)           bad "$desc -- output does not name '$needle'"; printf '%s\n' "$out" | sed 's/^/        /' ;;
    esac
  fi
}

# A minimal but honest ledger: a DESIGN.md with a rules section, a CLAUDE.md
# whose structure block matches the tree, and a contiguous ADR log.
scaffold_docs() {
  rm -rf "$WORK"; mkdir -p "$WORK/src" "$WORK/docs"; cd "$WORK" || exit 2
  git init -q .; git config user.email regression@local; git config user.name regression
  cat > DESIGN.md <<'MD'
# DESIGN.md — probe

## 1. What this is
A scratch project.

## 5. Build rules
- Exit codes are the contract and nothing else is. A check that cannot run is
  a failed check, and silent degradation is the failure mode engineered against.

## 6. Amendment procedure
Placeholder.
MD
  cat > CLAUDE.md <<'MD'
# CLAUDE.md — probe

## Current state
Summarised; see DESIGN.md §5 for the rules themselves.

## File structure as it stands

```
DESIGN.md                          spec
CLAUDE.md                          this file
DECISIONS.md                       ADR log
TASKS.md                           backlog
src/                               code
  m.py                             a module
docs/                              notes
```
MD
  printf '# DECISIONS.md\n\n## ADR-0001 — first\nBody.\n\n## ADR-0002 — second\nBody.\n\n## Spec gaps observed\n\n### SG-0001 — a gap\nBody.\n' > DECISIONS.md
  printf '# TASKS.md\n' > TASKS.md
  printf 'X = 1\n' > src/m.py
  printf 'notes\n' > docs/n.md
  git add -A >/dev/null 2>&1; git commit -qm init
}

echo
echo "T-006 -- drift guard, acceptance cases:"
scaffold_docs
run_drift 0 "clean ledger passes"

# T-006's Acceptance 1 -- a rules sentence pasted into CLAUDE.md must fail --
# was removed with the duplication sub-check itself (ADR-0028). Copying is no
# longer detected at all; DESIGN.md §5's Known limits says so. Do not re-add a
# case here without re-adding the check, and do not re-add the check without an
# incident to cite.

# Acceptance 2: delete a directory the structure block names.
scaffold_docs
rm -rf "$WORK/docs"
run_drift 2 "staleness: documented directory deleted" "docs/"

# A directory that exists but was never documented -- the half a reader cannot
# notice, since nothing in CLAUDE.md points at what is missing from it.
scaffold_docs
mkdir -p "$WORK/vendor" && printf 'x\n' > "$WORK/vendor/x.txt"
run_drift 2 "staleness: undocumented top-level directory" "vendor/"

# An ignored path is runtime state, not structure. devseed's own CLAUDE.md
# names .claude/in-flight.md and .claude/.hook-state/, which exist only
# mid-session; reporting their absence would make the guard cry wolf on every
# clean checkout, and a guard that cries wolf gets switched off.
scaffold_docs
printf 'scratch/\n' > "$WORK/.gitignore"
# awk, not `sed -i`: -i without a suffix and \n in a replacement are both GNU
# sed only -- BSD sed on the macOS leg takes the script as -i's backup suffix
# and dies (ADR-0025).
awk '1; /^docs\/ / { print "scratch/                           runtime scratch (ignored)" }' \
  "$WORK/CLAUDE.md" > "$WORK/CLAUDE.md.new" && mv "$WORK/CLAUDE.md.new" "$WORK/CLAUDE.md"
( cd "$WORK" && git add -A >/dev/null 2>&1 && git commit -qm ignore )
run_drift 0 "gitignored path named but absent is not drift"

# Orphans: an id cited in code that resolves to no entry in DECISIONS.md.
#
# The fixture ids are assembled at runtime rather than written literally, so
# this file does not flag ITSELF -- check 7 scans every tracked file for id
# references, and a deliberately-dangling id in a test fixture is
# indistinguishable from a real orphan. check-06-spec-gaps.sh dodges its own
# marker the same way. Caught by running the gate on this commit.
_ADR="ADR-00"; _ADR="${_ADR}99"
_SG="SG-00";   _SG="${_SG}99"

scaffold_docs
printf '\n# see %s\n' "$_ADR" >> "$WORK/src/m.py"
run_drift 2 "orphan: ADR cited with no entry" "$_ADR"

scaffold_docs
printf '\n# see %s\n' "$_SG" >> "$WORK/src/m.py"
run_drift 2 "orphan: spec-gap id cited with no entry" "$_SG"

# --- T-040: ids resolve across docs/adr/ AND docs/adr/archive/ ---------------
# ADR-0029 moved each ADR into its own file and made retirement a git mv into
# archive/. The property that has to hold is that RETIREMENT IS NOT DESTRUCTIVE:
# a citation of an archived entry still resolves, or nobody would ever archive
# anything and the log would fill with entries no one dares touch.
scaffold_docs
mkdir -p "$WORK/docs/adr/archive"
printf '# ADR-0001 — active one\n\n- **Status:** Accepted\n' > "$WORK/docs/adr/0001-active-one.md"
printf '# ADR-0002 — retired one\n\n- **Status:** Accepted\n' > "$WORK/docs/adr/archive/0002-retired-one.md"
# DECISIONS.md keeps the spec gaps inline; its ADR headings are gone, so a
# citation can only resolve via the directories.
printf '# DECISIONS.md\n\n## Spec gaps observed\n\n### SG-0001 — a gap\nBody.\n' > "$WORK/DECISIONS.md"
printf '\n# cites ADR-0002\n' >> "$WORK/src/m.py"
( cd "$WORK" && git add -A >/dev/null 2>&1 && git commit -qm adr )
run_drift 0 "citation resolving to an ARCHIVED ADR passes"

# And the negative: an id matching no file in either directory must fail. Same
# fixture, one digit different -- assembled at runtime so this suite does not
# flag itself, the same dodge the orphan cases above use.
_GONE="ADR-00"; _GONE="${_GONE}77"
printf '\n# cites %s\n' "$_GONE" >> "$WORK/src/m.py"
run_drift 2 "citation resolving to nothing fails" "$_GONE"

# Superseded integrity: a hole in the ADR sequence. The companion case -- an
# ADR deleted outright, caught by walking git history -- went with the walk
# itself (ADR-0028): it could not run in a shallow clone, so it read as
# coverage while providing none. Deleting the HIGHEST-numbered ADR is now
# undetected, which is why DESIGN.md §5's Known limits names it.
scaffold_docs
printf '\n## ADR-0004 — fourth\nBody.\n' >> "$WORK/DECISIONS.md"
run_drift 2 "superseded: ADR numbering not contiguous" "ADR-0003"

# Budget. The ceiling is lowered rather than the file inflated, so the case
# stays readable and does not depend on generating 300 lines of filler.
scaffold_docs
( cd "$WORK" && DRIFT_BUDGET_FAIL=5 DRIFT_BUDGET_WARN=2 bash "$DRIFT" >/dev/null 2>&1 )
[ "$?" = 2 ] && ok "budget: CLAUDE.md over ceiling rejected (exit 2)" \
             || bad "budget: CLAUDE.md over ceiling -- wanted exit 2"

# ---------------------------------------------------------------------------
# Mirror parity (agents and skills). Both compare a shipped directory against a
# devseed-local mirror by exact byte equality, in both directions.
#
# These get cases because the guard's own failure mode is silence: each opens
# with `[ -d ... ] || return 0`, so a mirror deleted wholesale disables the
# check rather than failing it. Without a case that FORCES a mismatch, a future
# edit that makes either return early passes this regression unnoticed.

drift_mirror() {           # want desc needle env...
  local want="$1" desc="$2" needle="$3"; shift 3
  local out got
  out="$( cd "$WORK" && env "$@" bash "$DRIFT" 2>&1 )"; got=$?
  if [ "$got" = "$want" ]; then ok "$desc (exit $got)"; else bad "$desc -- wanted exit $want, got $got"; fi
  [ "$got" != 1 ] || bad "$desc RETURNED 1 -- exit 1 does not block and must never be returned"
  if [ -n "$needle" ]; then
    case "$out" in
      *"$needle"*) ok "$desc -- names '$needle'" ;;
      *)           bad "$desc -- output does not name '$needle'"; printf '%s\n' "$out" | sed 's/^/        /' ;;
    esac
  fi
}

for KIND in agents skills; do
  case "$KIND" in
    agents) SHIP_VAR=DRIFT_AGENTS_SHIPPED; MIRR_VAR=DRIFT_AGENTS_MIRROR; REL=probe.md ;;
    skills) SHIP_VAR=DRIFT_SKILLS_SHIPPED; MIRR_VAR=DRIFT_SKILLS_MIRROR; REL=probe/SKILL.md ;;
  esac

  # Nested under docs/, which scaffold_docs already creates and documents --
  # a new top-level directory would trip the reverse-staleness check instead
  # and the case would pass for the wrong reason.
  SHIP="docs/ship"; MIRR="docs/mirror"

  # Identical -> clean.
  scaffold_docs
  mkdir -p "$(dirname "$WORK/$SHIP/$REL")" "$(dirname "$WORK/$MIRR/$REL")"
  printf 'body\n' > "$WORK/$SHIP/$REL"; cp "$WORK/$SHIP/$REL" "$WORK/$MIRR/$REL"
  drift_mirror 0 "$KIND parity: identical mirror passes" "" \
    "$SHIP_VAR=$SHIP" "$MIRR_VAR=$MIRR"

  # Contents differ -> caught.
  printf 'drifted\n' >> "$WORK/$MIRR/$REL"
  drift_mirror 2 "$KIND parity: differing mirror rejected" "$REL" \
    "$SHIP_VAR=$SHIP" "$MIRR_VAR=$MIRR"

  # Present in shipped, absent from mirror -> caught.
  rm -f "$WORK/$MIRR/$REL"
  drift_mirror 2 "$KIND parity: file missing from mirror rejected" "$REL" \
    "$SHIP_VAR=$SHIP" "$MIRR_VAR=$MIRR"

  # Present in mirror, absent from shipped -> caught.
  cp "$WORK/$SHIP/$REL" "$WORK/$MIRR/$REL"; rm -f "$WORK/$SHIP/$REL"
  drift_mirror 2 "$KIND parity: mirror-only file rejected" "$REL" \
    "$SHIP_VAR=$SHIP" "$MIRR_VAR=$MIRR"
done

# --- T-032: check 5 and drift.sh must agree ----------------------------------
# drift.sh's check_orphans duplicates check 5's done-task scan deliberately --
# it also runs standalone, where the rest of the gate may not have run. The
# copies once drifted on regex dialect (check 5 portable longhand, drift.sh an
# ERE interval some awks silently never match; ADR-0025) with nothing comparing
# them. These cases run BOTH copies against the same TASKS.md fixture and
# demand the same ruling: resolving hash passes both, hashless fails both,
# fabricated fails both -- the branch the first matrix run actually died in.
echo
echo "T-032 -- check 5 and drift.sh rule the same ledger the same way:"
scaffold
printf '\n## T-101 — hashed\n\n- **Status:** done\n- **Commit:** `%s`\n' \
  "$( cd "$WORK" && git rev-parse --short=8 HEAD )" >> "$WORK/TASKS.md"
( cd "$WORK" && git add -A >/dev/null 2>&1 && git commit -qm "ledger" )
run_gate  0 "done task with resolving hash: gate (check 5) passes"
run_drift 0 "done task with resolving hash: drift.sh agrees"

printf '\n## T-102 — hashless\n\n- **Status:** done\n- **Commit:** —\n' >> "$WORK/TASKS.md"
run_gate  2 "done task with no hash: gate (check 5) rejects"
run_drift 2 "done task with no hash: drift.sh agrees" "cites no commit hash"

scaffold
printf '\n## T-103 — fabricated\n\n- **Status:** done\n- **Commit:** `deadbee`\n' >> "$WORK/TASKS.md"
run_gate  2 "fabricated hash: gate (check 5) rejects"
run_drift 2 "fabricated hash: drift.sh agrees" "resolves to nothing"

# --- T-029: CI runs the real gate --------------------------------------------
# The CI-parity rule (DESIGN.md §5) held only because nobody edited a YAML
# file. One assertion, per the 2026-08 audit closure: the workflow contains
# the canonical invocation, tested by a suite CI itself runs. Self-disabling
# where the workflow is absent -- this suite also runs in consumer contexts.
echo
echo "T-029 -- CI invokes the real gate:"
# Derive the repo root from $GATE, which was resolved to an absolute path at
# script start -- by now the suite has cd'd into scratch projects, so a
# relative BASH_SOURCE lookup here would silently self-disable in devseed
# itself, which is the exact failure mode the assertion exists to catch.
WF="${GATE%/plugins/governed-dev/gates/gate.sh}/.github/workflows/gate.yml"
if [ ! -f "$WF" ]; then
  printf '  note: no .github/workflows/gate.yml -- consumer context, check self-disabled.\n'
elif grep -q 'bash plugins/governed-dev/gates/gate.sh' "$WF"; then
  ok "gate.yml carries the canonical line 'bash plugins/governed-dev/gates/gate.sh'"
else
  bad "gate.yml exists but lacks the canonical invocation -- CI is not running the real gate"
fi

echo
echo "summary: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ] || exit 2
exit 0
