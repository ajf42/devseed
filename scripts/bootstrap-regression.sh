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

printf '\n== 7. the shipped TASKS.md convention agrees with gate check 5 ==\n'
# A convention document that sanctions a state the gate rejects blocks the
# consumer on their first completed task, with a failure message telling them
# to record a hash that does not exist yet. The template is the one copy of
# this convention nothing was comparing against the check that enforces it.
#
# Run against $TARGET from section 4 -- a real git repo seeded from the real
# templates -- with the real gate.sh, so the ruling is observed, not assumed.
GATE="$ROOT/plugins/governed-dev/gates/gate.sh"

# seed_ledger <status> <commit-field>: reset the seeded ledger and append one
# task in the given state. The task heading is the template's own skeleton id.
seed_ledger() {
  git -C "$TARGET" checkout -- . >/dev/null 2>&1
  printf '\n## T-001 — first task\n\n- **Status:** %s\n- **Commit:** %s\n' \
    "$1" "$2" >> "$TARGET/TASKS.md"
}
gate_in_target() {         # want desc
  local want="$1" desc="$2" got
  ( cd "$TARGET" && bash "$GATE" ) >"$SCRATCH/gate.out" 2>&1; got=$?
  [ "$got" -ne 1 ] || bad "$desc RETURNED 1 -- exit 1 does not block"
  [ "$got" -eq "$want" ]; check $? "$desc (wanted exit $want, got $got)"
}

# The two states the two-commit flow passes through. Both must pass, or the
# flow the template describes cannot be followed to the end.
seed_ledger 'in-progress' '—'
gate_in_target 0 "in-progress with no hash yet passes the gate"
seed_ledger 'done' "\`$(git -C "$TARGET" rev-parse --short=8 HEAD)\`"
gate_in_target 0 "done with a resolving hash passes the gate"

# And the state the pre-correction convention sanctioned. Asserted here rather
# than taken on trust: it is the fact the rest of this section rests on.
seed_ledger 'done' '`pending`'
gate_in_target 2 "done with \`pending\` is rejected by the gate"
grep -q '5/7 task ledger' "$SCRATCH/gate.out"
check $? "...and it is check 5 that rejects it"

# The commit-hash bullet, joined into one string. Everything below reads this
# rather than the whole file, so an assertion cannot pass because some other
# bullet happens to contain the word.
BULLET="$(awk '
  /^- \*\*Commit hash\*\*/                { f = 1 }
  f && /^- / && !/^- \*\*Commit hash\*\*/ { f = 0 }
  f                                       { line = line " " $0 }
  END { print line }
' "$TEMPLATES/TASKS.md")"

# Every value the template OFFERS for the Commit field must be one the gate
# accepts. "Offers" is read narrowly and mechanically: an inline-code token on
# the commit-hash bullet, in a sentence that does not say the gate rejects it.
# A token the template names only to forbid is not an offer.
#
# Status values and filenames are dropped -- the bullet cites `gate.sh` and
# `done` as prose, not as things to put in the Commit field. Sentence splitting
# is awk, not `sed 's/\. /.\n/'`: \n in a replacement is GNU-only (ADR-0025).
OFFERED="$(printf '%s\n' "$BULLET" | awk '
  { n = split($0, s, /\. /)
    for (i = 1; i <= n; i++) if (s[i] !~ /reject/) print s[i] }
' | grep -o '`[^`]*`' | tr -d '`' | sort -u)"

OFFENDING=0
while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  case "$tok" in
    todo|in-progress|done|blocked|dropped) continue ;;
    *.*|*' '*)                             continue ;;
  esac
  OFFENDING=$((OFFENDING+1))
  seed_ledger 'done' "\`$tok\`"
  gate_in_target 0 "the Commit value the template offers (\`$tok\`) survives the gate"
done <<EOF
$OFFERED
EOF
[ "$OFFENDING" -eq 0 ] && ok "the commit bullet offers no literal Commit value (nothing to reject)"

# Criterion 2 restated over the whole file: `pending` may appear only as a
# value the gate rejects. Sentence-scoped, since the rejection clause wraps.
STRAY="$(awk '{ line = line " " $0 }
  END { n = split(line, s, /\. /)
        for (i = 1; i <= n; i++) if (s[i] ~ /pending/ && s[i] !~ /reject/) print s[i] }
' "$TEMPLATES/TASKS.md")"
[ -z "$STRAY" ] || printf '    sanctions it: %s\n' "$STRAY" >&2
[ -z "$STRAY" ]; check $? "templates/TASKS.md names \`pending\` only as a rejected value"

# The bullet must point at the enforcer and at the state to hold meanwhile,
# or a consumer hitting the failure has nothing to read. Guards the section
# above from passing because the bullet stopped saying anything at all.
case "$BULLET" in *'check 5'*) true ;; *) false ;; esac
check $? "the commit bullet names check 5 as the enforcer"
case "$BULLET" in *'in-progress'*) true ;; *) false ;; esac
check $? "the commit bullet names in-progress as the in-between state"

git -C "$TARGET" checkout -- . >/dev/null 2>&1

printf '\n---------------------------------------------\n'
printf 'bootstrap-regression: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 2
exit 0
