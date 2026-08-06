#!/usr/bin/env bash
# bootstrap-regression.sh -- asserts the /bootstrap skill's WIRING, in a scratch
# repo outside this one. devseed-only; not shipped.
#
# What this can and cannot test, stated so the coverage is not overread:
#
#   CAN  -- that every file the skill says it copies actually exists in
#           templates/, that the copy produces a governed project, that
#           gate.sh arrives as the documented no-op rather than a generated
#           gate, and that no shipped agent or skill cites a .claude/rules/
#           path the bootstrap does not install.
#   CANNOT -- the interview. That is agent behaviour and is verified by
#           inspection, not here.
#
# The class of defect this exists for: a skill that names a template which is
# not there, or hands the scribe a path that does not yet exist, fails at run
# time and looks like an agent error rather than the wiring error it is.
#
# Deliberately NOT `set -e`: a failed assertion must be counted and reported,
# not abort the run at the first one. Exit 0 pass, 2 fail -- never 1.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$ROOT/plugins/governed-dev/templates"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1" >&2; }
check(){ if [ "$1" = 0 ]; then ok "$2"; else bad "$2"; fi; }

SCRATCH="$(mktemp -d 2>/dev/null || mktemp -d -t bootstrap)"
trap 'rm -rf "$SCRATCH"' EXIT

printf '\n== 1. templates/ contains everything the skill claims to copy ==\n'
for f in DESIGN.md CLAUDE.md DECISIONS.md TASKS.md gate.sh .gitignore .gitattributes \
         rules/precedence.md rules/ambiguity.md rules/delegation.md rules/ledger.md; do
  [ -f "$TEMPLATES/$f" ]; check $? "templates/$f exists"
done

printf '\n== 2. the SKILL.md names every file it copies, and no file it does not ==\n'
# This is the assertion that actually guards the skill. A skill naming a
# template that is not there fails at run time and reads as an agent error.
SKILL="$ROOT/plugins/governed-dev/skills/bootstrap/SKILL.md"
[ -f "$SKILL" ]; check $? "bootstrap/SKILL.md exists"

for f in DESIGN.md CLAUDE.md DECISIONS.md TASKS.md gate.sh .gitignore .gitattributes; do
  grep -qF "$f" "$SKILL"; check $? "SKILL.md names $f"
done
grep -qF 'rules/' "$SKILL";           check $? "SKILL.md names rules/"
grep -qF 'activity.jsonl' "$SKILL";   check $? "SKILL.md creates .claude/activity.jsonl"

# The scribe holds Read and Edit and no Write, so it cannot create a file that
# does not yet exist. Any skill that DELEGATES a write to it must say so, or the
# run-time failure reads as an agent error rather than the wiring error it is.
# bootstrap is exempt: it delegates nothing, it creates the files itself.
for s in task adr; do
  grep -qiE 'no .?.Write.|cannot create' "$ROOT/plugins/governed-dev/skills/$s/SKILL.md"
  check $? "$s/SKILL.md states the scribe cannot create files"
done

printf '\n== 3. templates/gate.sh is the documented no-op, not a working gate ==\n'
# Asserted against the TEMPLATE, not against a copy this script just made --
# copying then comparing would be true by construction and would still pass if
# the skill were rewritten to generate a gate.
grep -q 'PLACEHOLDER' "$TEMPLATES/gate.sh"
check $? "templates/gate.sh declares itself a placeholder"

grep -qE 'pytest|npm run|ruff|eslint|check-0' "$TEMPLATES/gate.sh"; [ $? -ne 0 ]
check $? "templates/gate.sh runs no actual checks"

bash "$TEMPLATES/gate.sh" >/dev/null 2>&1; [ $? -eq 0 ]
check $? "templates/gate.sh exits 0 (no-op), never 1"

# An executable `set -e` line, not the comment explaining why it is absent.
grep -qE '^[[:space:]]*set -[a-z]*e' "$TEMPLATES/gate.sh"; [ $? -ne 0 ]
check $? "templates/gate.sh does not use 'set -e' (which would exit 1, not 2)"

# The skill must say "verbatim" and must not instruct generation.
grep -qi 'verbatim' "$SKILL"
check $? "SKILL.md requires gate.sh be copied verbatim"
grep -qiE 'generat(e|ing) a working gate|write a gate' "$SKILL"; [ $? -ne 0 ]
check $? "SKILL.md does not instruct generating a gate"

printf '\n== 4. a seeded project is clean under the real drift guard ==\n'
TARGET="$SCRATCH/newproj"
mkdir -p "$TARGET/.claude/rules" && git -C "$TARGET" init -q .
for f in DESIGN.md CLAUDE.md DECISIONS.md TASKS.md; do
  sed 's/{{PROJECT_NAME}}/newproj/g' "$TEMPLATES/$f" > "$TARGET/$f"
done
cp "$TEMPLATES/gate.sh" "$TEMPLATES/.gitignore" "$TEMPLATES/.gitattributes" "$TARGET/"
cp "$TEMPLATES"/rules/*.md "$TARGET/.claude/rules/"
: > "$TARGET/.claude/activity.jsonl"
git -C "$TARGET" add -A >/dev/null 2>&1
git -C "$TARGET" -c user.email=b@b -c user.name=b commit -qm "bootstrap" >/dev/null 2>&1

grep -q '{{PROJECT_NAME}}' "$TARGET"/*.md; [ $? -ne 0 ]
check $? "no {{PROJECT_NAME}} left unsubstituted"
grep -q 'eol=lf' "$TARGET/.gitattributes"
check $? "seeded .gitattributes carries the eol=lf rule"

# The point of this section: a freshly bootstrapped project must PASS the drift
# guard on its first run. A dangling devseed id in any shipped template fails
# the consumer's gate in a repo they have not touched -- which is exactly when
# a reader decides whether the tool is trustworthy.
( cd "$TARGET" && bash "$ROOT/plugins/governed-dev/gates/drift.sh" ) >"$SCRATCH/drift.out" 2>&1
DRC=$?
[ "$DRC" -eq 0 ] || sed 's/^/    /' "$SCRATCH/drift.out" >&2
[ "$DRC" -eq 0 ]
check $? "a freshly bootstrapped project passes the drift guard"

printf '\n== 5. no dangling .claude/rules/ references in shipped content ==\n'
MISSING=0
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  [ -f "$TARGET/$ref" ] || { printf '    dangling: %s\n' "$ref" >&2; MISSING=$((MISSING+1)); }
done <<EOF
$(grep -rhoE '\.claude/rules/[a-z-]+\.md' \
    "$ROOT/plugins/governed-dev/agents" \
    "$ROOT/plugins/governed-dev/skills" \
    "$ROOT/plugins/governed-dev/hooks" 2>/dev/null | sort -u)
EOF
[ "$MISSING" -eq 0 ]
check $? "every .claude/rules/ path cited by a shipped agent/skill/hook resolves"

printf '\n== 6. nothing shipped from templates/ cites a devseed id ==\n'
# Anything copied into a consumer must not cite devseed's own ADR/SG numbers --
# they resolve to nothing in that project's DECISIONS.md, and the drift guard
# scans every tracked file, so the citation fails their gate on the first
# commit. Section 4 proves the consequence; this names the cause, per file, so
# a failure says which one.
#
# templates/DECISIONS.md is exempt: it DEFINES ADR-0001 and SG-0001 as skeleton
# examples rather than citing them, and the guard does not scan DECISIONS.md.
# README.md is exempt: it is not copied into a consumer project.
for f in $(cd "$TEMPLATES" && ls -A | grep -vE '^(DECISIONS\.md|README\.md|rules)$'); do
  grep -qE 'ADR-[0-9]{4}|SG-[0-9]{4}' "$TEMPLATES/$f"; [ $? -ne 0 ]
  check $? "templates/$f cites no devseed ADR or SG number"
done
for f in "$TEMPLATES"/rules/*.md; do
  grep -qE 'ADR-[0-9]{4}|SG-[0-9]{4}' "$f"; [ $? -ne 0 ]
  check $? "templates/rules/${f##*/} cites no devseed ADR or SG number"
done

grep -rq 'devseed' "$TEMPLATES/rules/"; [ $? -ne 0 ]
check $? "templates/rules/ does not mention devseed"

printf '\n---------------------------------------------\n'
printf 'bootstrap-regression: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 2
exit 0
