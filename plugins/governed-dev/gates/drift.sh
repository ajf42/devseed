#!/usr/bin/env bash
#
# drift.sh -- structural drift guard across the four ledger documents.
#
# The other checks ask "is the code done?". This one asks "do the documents
# still describe the repository?" -- the failure class precedence.md calls
# STRUCTURAL disagreement, as opposed to ordinary staleness. It is the
# mechanical version of a review that was previously done by hand, and found
# four real defects doing it (T-012..T-015).
#
# Six checks, all read-only:
#
#   1 staleness    every path named in CLAUDE.md's structure block exists, and
#                  every top-level directory on disk is named there.
#   2 budget       CLAUDE.md <= 300 lines, warned at 250.
#   3 orphans      every ADR-NNNN cited anywhere resolves to a file in docs/adr/
#                  or docs/adr/archive/ (or, where a project keeps ADRs inline,
#                  to a heading in DECISIONS.md); every SG-NNNN resolves in
#                  DECISIONS.md; every done task cites a commit that exists.
#   4 superseded   ADR numbers are contiguous -- no number silently vanishes.
#   5 index parity where DECISIONS.md is a generated index over docs/adr/, the
#                  two must agree; the gate verifies, it never regenerates.
#   6 mirror parity where a project mirrors hooks.json into .claude/settings.json,
#                  the two must agree on events, matchers and async flags; and the
#                  agent roster mirror must match the shipped one byte for byte.
#
# TWO SUB-CHECKS WERE REMOVED (ADR-0028), both as dead rules under DESIGN.md
# SS6's never-fired test: a duplication check that measured whether CLAUDE.md
# copied >=12 contiguous words out of a DESIGN.md rules section, and a walk of
# DECISIONS.md's git history asserting no ADR had ever been deleted. The second
# was silently inert under a default shallow checkout. Do not reinstate either
# without an incident to cite.
#
# EXIT CODES: 0 = no drift, 2 = drift found. NEVER 1 -- see gate.sh.
#
# NO SIDE EFFECTS. Reports drift; changes nothing. Unlike the other checks this
# one does NOT stop at the first finding: a drift report is only useful if it
# is the whole list, so findings accumulate and the exit happens at the end.
#
# Usage:  bash drift.sh            standalone / CI
#         (also run as gate check 7 via check-07-drift.sh)
#
# Deliberately not `set -e`: exit codes are controlled explicitly, and -e would
# surface a finding as exit 1, which does not block.
set -uo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  printf 'GATE FAIL: drift.sh requires bash. Run it as: bash %s\n' "$0" >&2
  exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/lib.sh" ] || {
  printf 'GATE FAIL: %s/lib.sh is missing. The gate is incomplete.\n' "$HERE" >&2
  exit 2
}
# shellcheck source=lib.sh
. "$HERE/lib.sh"   # sets ROOT and cds into it; provides die/note/have

CHECK="7/7 drift"

BUDGET_FAIL="${DRIFT_BUDGET_FAIL:-300}"
BUDGET_WARN="${DRIFT_BUDGET_WARN:-250}"

FOUND=0

# drift <file[:line]> <what is wrong> <what to do about it>
# Failure messages are instructions, not complaints (DESIGN.md §5) -- an agent
# reads this text and acts on it, so every finding carries its own fix.
drift() {
  FOUND=$((FOUND + 1))
  printf 'DRIFT [%s] %s\n' "$CHECK" "$1" >&2
  printf '  %s\n' "$2" >&2
  printf '  Fix: %s\n' "$3" >&2
}

warn() { printf 'drift: WARNING %s -- %s\n' "$1" "$2" >&2; }
skip() { printf 'drift: %s\n' "$1" >&2; }

# ---------------------------------------------------------------------------
# Check 1 -- staleness
#
# CLAUDE.md's structure block is an indented tree. A line's indentation picks
# its parent; the first run of two-or-more spaces ends the path column and
# begins commentary. Commentary is ignored -- it routinely names other files
# ("DESIGN.md vs CLAUDE.md authority") and treating those as paths would
# invent children that were never claimed to exist.
# ---------------------------------------------------------------------------
TREE_AWK='
BEGIN { top = 0 }
/^## / { insec = (tolower($0) ~ /structure/); next }
!insec { next }
/^[ \t]*```/ { fence = !fence; next }
!fence { next }
/^[ \t]*$/ { next }
{
  match($0, /^ */); ind = RLENGTH
  rest = substr($0, ind + 1)
  if (match(rest, /  +/)) rest = substr(rest, 1, RSTART - 1)

  while (top > 0 && sind[top] >= ind) top--
  prefix = (top > 0) ? spre[top] : ""

  n = split(rest, names, " ")
  for (i = 1; i <= n; i++) {
    nm = names[i]
    # Path-like means it ends in "/" or contains a ".". Bare words are the
    # second column of the hook table (Setup, SubagentStop) and prose, and
    # must not be mistaken for filenames.
    if (nm !~ /\/$/ && nm !~ /\./) continue
    printf "%d\t%s\n", FNR, prefix nm
    if (nm ~ /\/$/) { top++; sind[top] = ind; spre[top] = prefix nm }
  }
}
'

check_staleness() {
  if [ ! -f CLAUDE.md ]; then
    skip "check 1 (staleness): no CLAUDE.md -- nothing to check."
    return
  fi

  local rows
  rows="$(awk "$TREE_AWK" CLAUDE.md 2>/dev/null)"

  if [ -z "$rows" ]; then
    skip "check 1 (staleness): CLAUDE.md has no fenced structure block -- nothing to check."
    return
  fi

  local line path matches
  while IFS="$(printf '\t')" read -r line path; do
    [ -n "${path:-}" ] || continue

    case "$path" in
      *[*?[]*)
        # A glob stands for a family of files. One match is enough; zero means
        # the family named in the documentation is gone.
        matches=( $path )
        [ -e "${matches[0]}" ] && continue
        drift "CLAUDE.md:$line" \
"the structure block names \`$path\`, which matches nothing on disk." \
"restore the files, or correct the pattern in CLAUDE.md's structure block. A structure block is read as the map of the repository; a path in it that resolves to nothing sends the next session looking for something that is not there."
        continue
        ;;
    esac

    [ -e "$path" ] && continue

    # Ignored paths are runtime state, not structure -- .claude/in-flight.md
    # and .claude/.hook-state/ exist only mid-session. Their absence is normal
    # and must not be reported as drift.
    if git check-ignore -q -- "$path" 2>/dev/null; then continue; fi

    drift "CLAUDE.md:$line" \
"the structure block names \`$path\`, which does not exist." \
"create it, or delete the line from CLAUDE.md's structure block. If the path is generated at runtime, add it to .gitignore -- ignored paths are exempt from this check."
  done <<EOF
$rows
EOF

  # The other direction. A structure block that omits a real directory is the
  # more dangerous half: the reader cannot notice what was never mentioned.
  local d name
  for d in */ .*/ ; do
    [ -d "$d" ] || continue
    name="${d%/}"
    case "$name" in .|..|.git) continue ;; esac
    git check-ignore -q -- "$name" 2>/dev/null && continue

    printf '%s\n' "$rows" | cut -f2 | grep -q "^$(printf '%s' "$name" | sed 's/[][\.*^$/]/\\&/g')/" && continue

    drift "CLAUDE.md" \
"top-level directory \`$name/\` exists on disk but appears nowhere in CLAUDE.md's structure block." \
"add it to the structure block with a one-line description of what it holds, or remove the directory. An undocumented directory is invisible to anyone reading CLAUDE.md as the map of the repository."
  done
}

# ---------------------------------------------------------------------------
# Check 2 -- budget
#
# The ceiling is the point, not an aspiration: CLAUDE.md is read in full every
# session, and one that grows without bound stops being read carefully. An
# unread current-state record is worse than none -- it still looks
# authoritative. The warning exists so compression happens on a normal commit
# rather than as an emergency on the commit that crosses the line.
# ---------------------------------------------------------------------------
check_budget() {
  [ -f CLAUDE.md ] || return 0

  local n
  n="$(wc -l < CLAUDE.md | tr -d ' ')"

  if [ "$n" -gt "$BUDGET_FAIL" ]; then
    drift "CLAUDE.md:$n" \
"CLAUDE.md is $n lines, over its hard ceiling of $BUDGET_FAIL." \
"compress it before continuing, routing detail by kind: constraints to DESIGN.md, rationale to DECISIONS.md as an ADR, per-directory mechanics to a README.md in that directory, pending work to TASKS.md, superseded state deleted outright. Leave a one-line pointer in place of anything moved."
  elif [ "$n" -gt "$BUDGET_WARN" ]; then
    warn "CLAUDE.md:$n" \
"$n lines, past the $BUDGET_WARN-line warning mark and $((BUDGET_FAIL - n)) short of the $BUDGET_FAIL-line ceiling. Compress on this commit, not on the one that crosses it."
  fi
}

# ---------------------------------------------------------------------------
# Check 3 -- orphans
#
# TWO LAYOUTS, both supported. devseed keeps each ADR in its own file under
# docs/adr/ with DECISIONS.md generated as an index (ADR-0029); a consumer
# project that has not migrated keeps every ADR inline in DECISIONS.md. The
# layout is detected, not configured -- docs/adr/ exists or it does not.
#
# In per-file mode an id resolves against docs/adr/ AND docs/adr/archive/.
# Archived is not gone: an ADR whose subject was deleted still explains why the
# repository looks the way it does, and a citation that stops resolving because
# an entry was retired would make retirement destructive, which is exactly what
# the archive exists to avoid.
#
# Spec-gap ids stay in DECISIONS.md under "Spec gaps observed" in both layouts.
# ---------------------------------------------------------------------------
ADR_DIR="${DRIFT_ADR_DIR:-docs/adr}"
ADR_ARCHIVE="${DRIFT_ADR_ARCHIVE:-docs/adr/archive}"

# adr_resolves <ADR-NNNN> -- true if the id has an entry in either layout.
adr_resolves() {
  local id="$1" num="${1#ADR-}"
  if [ -d "$ADR_DIR" ]; then
    ls "$ADR_DIR/$num"-*.md >/dev/null 2>&1 && return 0
    ls "$ADR_ARCHIVE/$num"-*.md >/dev/null 2>&1 && return 0
    return 1
  fi
  grep -q "^## $id\b" DECISIONS.md 2>/dev/null
}

check_orphans() {
  require_git

  if [ ! -f DECISIONS.md ]; then
    skip "check 3 (orphans): no DECISIONS.md -- id references cannot be resolved."
  else
    # Every tracked file except DECISIONS.md itself, which is where the ids are
    # DEFINED, and the activity log, which is machine-written and append-only:
    # a stale id in the audit trail is history, not drift, and correcting it by
    # hand would be the real violation (ADR-0003).
    local files line f lno ident
    files="$(git ls-files 2>/dev/null | grep -v '^DECISIONS\.md$' | grep -v '^\.claude/activity\.jsonl$')"

    while IFS= read -r f; do
      [ -n "$f" ] && [ -f "$f" ] || continue
      # grep -no gives "<line>:<id>" -- the number and the matched id and
      # nothing else, which is exactly the pair this needs.
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        lno="${line%%:*}"
        ident="${line#*:}"
        case "$ident" in
          ADR-*) adr_resolves "$ident" && continue
                 if [ -d "$ADR_DIR" ]; then
                   drift "$f:$lno" \
"cites $ident, which matches no file in $ADR_DIR/ or $ADR_ARCHIVE/." \
"add the ADR as $ADR_DIR/${ident#ADR-}-<short-slug>.md and re-run scripts/rebuild-adr-index.sh, or correct the reference. A decision cited by number that nobody can look up is indistinguishable from one that was never made. Retiring an ADR means moving it to $ADR_ARCHIVE/, never deleting it -- ids resolve forever."
                 else
                   drift "$f:$lno" \
"cites $ident, which has no \"## $ident\" heading in DECISIONS.md." \
"add the ADR to DECISIONS.md, or correct the reference. A decision cited by number that nobody can look up is indistinguishable from one that was never made."
                 fi
                 ;;
          SG-*)  grep -q "^### $ident\b" DECISIONS.md 2>/dev/null && continue
                 drift "$f:$lno" \
"cites $ident, which has no \"### $ident\" heading under 'Spec gaps observed' in DECISIONS.md." \
"record the gap in DECISIONS.md -- what was ambiguous, what was assumed, what depends on it -- or correct the reference."
                 ;;
        esac
      done <<EOF
$(grep -noE '(ADR|SG)-[0-9]{4}' "$f" 2>/dev/null | sort -u -t: -k2 )
EOF
    done <<EOF
$files
EOF
  fi

  # Done tasks must cite a commit that resolves. Check 5 of the gate asserts
  # the same thing; the duplication is deliberate, because drift.sh is also run
  # standalone in CI (T-009) where the rest of the gate may not have run.
  [ -f TASKS.md ] || return 0

  # The hash regex is check 5's, kept textually identical on purpose: written
  # longhand (7+ hex chars in backticks) because ERE interval expressions like
  # {7,} are not supported by every awk, and on one that lacks them the match
  # never fires -- every done task would read as hashless (ADR-0025). The two
  # copies are asserted to agree by scripts/gate-regression.sh (T-032).
  local rows task hash lno
  rows="$(awk '
    function flush() { if (t != "" && d == 1) printf "%s\t%s\t%s\n", tl, t, h }
    /^## /            { flush(); d = 0; h = ""; t = ""
                        if ($0 ~ /^## T-/) { t = $0; tl = FNR }
                        next }
    /\*\*Status:\*\*/ { if ($0 ~ /done/) d = 1 }
    /\*\*Commit:\*\*/ { if (match($0, /`[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*`/))
                          h = substr($0, RSTART + 1, RLENGTH - 2) }
    END               { flush() }
  ' TASKS.md)"

  while IFS="$(printf '\t')" read -r lno task hash; do
    [ -n "${task:-}" ] || continue
    if [ -z "${hash:-}" ]; then
      drift "TASKS.md:$lno" \
"${task#\#\# } is marked done but cites no commit hash." \
"record the hash of the commit that completed it, or set the status back to in-progress. A task is not done until it points at the commit that did it."
    elif [ "$(git cat-file -t "$hash" 2>/dev/null)" != "commit" ]; then
      drift "TASKS.md:$lno" \
"${task#\#\# } cites commit $hash, which resolves to nothing in this repository." \
"correct it to the real hash, or set the status back to in-progress. A hash that resolves to nothing is a claim with no evidence behind it."
    fi
  done <<EOF
$rows
EOF
}

# ---------------------------------------------------------------------------
# Check 4 -- superseded integrity
#
# Contiguity only. A hole in the numbering means an entry was removed, or one
# was numbered by guessing rather than by taking the next number. The stronger
# git-history witness was removed in ADR-0028: it could not run in a shallow
# clone, which is the default checkout, so it read as coverage while providing
# none. Deleting the highest-numbered ADR is therefore NOT caught -- stated in
# DESIGN.md SS5's Known limits rather than left to be discovered.
# ---------------------------------------------------------------------------
check_superseded() {
  [ -f DECISIONS.md ] || return 0
  require_git

  # Same two layouts as check 3. Per-file: the ids are the filenames, archive
  # included -- an archived ADR still occupies its number forever, so omitting
  # the archive would read every retirement as a hole.
  local cur max n missing
  if [ -d "$ADR_DIR" ]; then
    cur="$( { ls "$ADR_DIR"/*.md "$ADR_ARCHIVE"/*.md 2>/dev/null; } \
            | sed 's#.*/##' | grep -oE '^[0-9]{4}' | sed 's/^/ADR-/' | sort -u)"
  else
    cur="$(grep -oE '^## ADR-[0-9]{4}' DECISIONS.md 2>/dev/null | grep -oE 'ADR-[0-9]{4}' | sort -u)"
  fi
  [ -n "$cur" ] || return 0

  # Contiguity. A hole means an ADR was removed, or one was numbered by
  # guessing rather than by taking the next number.
  max="$(printf '%s\n' "$cur" | sed 's/ADR-//' | sort -n | tail -1)"
  missing=""
  for n in $(seq 1 "$((10#$max))"); do
    printf '%s\n' "$cur" | grep -q "^ADR-$(printf '%04d' "$n")$" || \
      missing="$missing ADR-$(printf '%04d' "$n")"
  done
  if [ -n "$missing" ]; then
    drift "DECISIONS.md" \
"the ADR numbers are not contiguous -- ADR-$(printf '%04d' "$((10#$max))") exists but${missing} do not." \
"restore the missing entries, or renumber so the sequence has no holes. A gap reads as a deleted decision, and a decision log that can lose entries cannot be trusted about the ones it still has."
  fi

}

# ---------------------------------------------------------------------------
# Check 5 -- ADR index parity
#
# Where DECISIONS.md is a GENERATED index over docs/adr/ (ADR-0029), the index
# and the directory are one fact in two places, and nothing else in the
# repository would notice them parting: a renamed, added, archived or
# re-statused ADR leaves the index silently wrong, and the index is what a
# reader scans first.
#
# This is the check .claude/rules/ledger.md's lifecycle rule names as its
# enforcement, per ADR-0023's discipline that a new rule arrives with its check
# named rather than resting on memory.
#
# THE GATE DOES NOT REGENERATE ANYTHING. It runs the generator's --print mode,
# which writes nothing, and compares. Verification only, no side effects
# (DESIGN.md SS5) -- the rule T-030 now tests in CI. The generator is the single
# implementation of the derivation; this check owns no second copy of it.
#
# WHAT TRIGGERS IT is the marker DECISIONS.md carries, not the mere existence
# of docs/adr/. A project may keep per-file ADRs and a hand-written DECISIONS.md
# -- devseed's own scripts/ is dev tooling and does not ship, so a consumer that
# adopts the layout without the generator is in a legitimate configuration, and
# failing their gate over a file they never had is a false positive on a correct
# change. Only a file that CLAIMS to be generated is held to matching.
# ---------------------------------------------------------------------------
ADR_INDEX_GEN="${DRIFT_ADR_INDEX_GEN:-scripts/rebuild-adr-index.sh}"
ADR_INDEX_MARK="${DRIFT_ADR_INDEX_MARK:-<!-- GENERATED FILE.}"

check_adr_index() {
  [ -d "$ADR_DIR" ] || return 0
  [ -f DECISIONS.md ] || return 0
  grep -qF "$ADR_INDEX_MARK" DECISIONS.md 2>/dev/null || return 0

  if [ ! -f "$ADR_INDEX_GEN" ]; then
    drift "$ADR_INDEX_GEN" \
"DECISIONS.md declares itself generated, but the generator $ADR_INDEX_GEN is missing, so nothing can verify or rebuild it." \
"restore $ADR_INDEX_GEN, or remove the generated-file marker from DECISIONS.md and maintain it by hand. A file that claims to be generated by a script nobody has is a claim no reader can check."
    return
  fi

  local want got
  want="$(bash "$ADR_INDEX_GEN" --print 2>/dev/null)"
  if [ -z "$want" ]; then
    drift "$ADR_INDEX_GEN" \
"the ADR index generator produced no output, so the committed DECISIONS.md cannot be verified against $ADR_DIR/." \
"run: bash $ADR_INDEX_GEN --print, and fix whatever it reports. A parity check that cannot run is a failed check, not a skip."
    return
  fi

  # Compared with CR stripped from both sides. Only *.sh is pinned to LF
  # (SG-0009), so this file checks out CRLF on Windows and would otherwise
  # differ from the generator's LF output on every Windows checkout -- a
  # guaranteed false positive on a correct tree, and one the matrix would have
  # found the hard way (ADR-0025's class).
  got="$(tr -d '\r' < DECISIONS.md)"
  want="$(printf '%s' "$want" | tr -d '\r')"
  [ "$want" = "$got" ] && return 0

  drift "DECISIONS.md" \
"the ADR index no longer matches $ADR_DIR/ -- an entry was added, renamed, archived, or re-statused without the index being rebuilt." \
"run scripts/rebuild-adr-index.sh and commit the result. Do not hand-edit the index: everything above the 'Spec gaps observed' heading is generated from the ADR files, and an edit there is discarded on the next rebuild while looking authoritative until then."
}

# ---------------------------------------------------------------------------
# Check 6 -- hook wiring parity
#
# Where a project both ships hooks.json and mirrors it into .claude/settings.json
# (devseed does; ADR-0011), the two are one wiring in two files. The SCRIPTS are
# shared, so the drift surface is exactly the event set, the matchers and the
# async flags -- and nothing else in the repository would notice them parting.
#
# Self-disabling: a consumer that installs the plugin has no hooks.json of its
# own, so the pair does not exist and the check does not run.
# ---------------------------------------------------------------------------
MIRROR="${DRIFT_HOOKS_MIRROR:-.claude/settings.json}"
SHIPPED="${DRIFT_HOOKS_SHIPPED:-plugins/governed-dev/hooks/hooks.json}"

# jq location, duplicated from hooks/lib.sh _jq_dir() rather than shared: the
# two libs are separately sourced deliverables (one by the gate, one by the
# hooks) and neither may depend on the other. winget installs jq into a Links
# directory that only reaches processes started after the install, so a
# freshly installed jq looks missing until the shell is restarted.
find_jq() {
  have jq && return 0
  local d
  for d in "/c/Program Files/jq" "/c/ProgramData/chocolatey/bin" \
           "$HOME/AppData/Local/Microsoft/WinGet/Links" \
           "/usr/local/bin" "/opt/homebrew/bin"; do
    if [ -x "$d/jq" ] || [ -x "$d/jq.exe" ]; then
      PATH="$d:$PATH"; export PATH; return 0
    fi
  done
  d="$(ls -d "${LOCALAPPDATA:-$HOME/AppData/Local}"/Microsoft/WinGet/Packages/jqlang.jq_* 2>/dev/null | head -1)"
  [ -n "$d" ] && [ -e "$d/jq.exe" ] && { PATH="$d:$PATH"; export PATH; return 0; }
  return 1
}

# Reduce a wiring file to a comparable shape: one line per event per hook, as
# event<TAB>matcher<TAB>script<TAB>flags. The command STRING is deliberately
# not compared -- the two files point at different roots on purpose, which is
# the entire reason the mirror exists. Only the script's basename carries over.
HOOK_JQ='
  .hooks
  | to_entries[]
  | .key as $event
  | .value[]
  | (.matcher // "*") as $m
  | .hooks[]
  | [ $event,
      $m,
      (.command | sub("^.*/"; "") | sub("\"$"; "")),
      ((if .async      then "async"      else empty end),
       (if .asyncRewake then "asyncRewake" else empty end))
      | tostring
    ]
  | @tsv
'

check_hook_parity() {
  if [ ! -f "$SHIPPED" ] || [ ! -f "$MIRROR" ]; then
    return 0
  fi

  if ! find_jq; then
    drift "$MIRROR" \
"jq is not installed, so the hook wiring in $SHIPPED and $MIRROR cannot be compared." \
"install jq -- Windows: winget install --id jqlang.jq -e; macOS: brew install jq; Debian: sudo apt-get install jq -- then re-run. A parity check that cannot run is a failed check, not a skip."
    return
  fi

  local a b d
  a="$(jq -r "$HOOK_JQ" "$SHIPPED" 2>/dev/null | sort)"
  b="$(jq -r "$HOOK_JQ" "$MIRROR" 2>/dev/null | sort)"

  if [ -z "$a" ] || [ -z "$b" ]; then
    drift "$MIRROR" \
"one of $SHIPPED / $MIRROR could not be parsed as hook wiring." \
"check both files are valid JSON with a top-level \"hooks\" object, then re-run."
    return
  fi

  [ "$a" = "$b" ] && return 0

  d="$(diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") 2>/dev/null | sed 's/^/    /')"
  drift "$MIRROR" \
"the hook wiring has diverged from $SHIPPED. Lines are event/matcher/script/flags; \"<\" is $SHIPPED, \">\" is $MIRROR:
$d" \
"bring $MIRROR back into line with $SHIPPED, which is the source of truth. Only the event set, matchers, script names and async flags are compared -- the command paths differ on purpose, since the mirror points at the working tree and the shipped file at the installed plugin."
}

# The agent roster is mirrored for the same reason the hook wiring is: an
# installed plugin pins to a commit SHA and goes stale, so devseed cannot
# dogfood a roster it only ships (ADR-0011, ADR-0014). Unlike the hook wiring,
# these files carry no path differences at all, so the test is exact equality --
# any difference is drift, with no legitimate variation to allow for.
#
# Self-disabling in the same way: a consumer has no plugins/governed-dev/agents/
# and so is not checked.
AGENTS_SHIPPED="${DRIFT_AGENTS_SHIPPED:-plugins/governed-dev/agents}"
AGENTS_MIRROR="${DRIFT_AGENTS_MIRROR:-.claude/agents}"

check_agent_parity() {
  [ -d "$AGENTS_SHIPPED" ] || return 0
  [ -d "$AGENTS_MIRROR" ] || return 0

  local f base
  for f in "$AGENTS_SHIPPED"/*.md; do
    [ -e "$f" ] || continue
    base="${f##*/}"
    if [ ! -f "$AGENTS_MIRROR/$base" ]; then
      drift "$AGENTS_MIRROR/$base" \
"agent \`$base\` ships in $AGENTS_SHIPPED but is missing from the $AGENTS_MIRROR mirror." \
"copy it: cp $f $AGENTS_MIRROR/. devseed loads its roster from the mirror, so an agent that exists only in the plugin is one devseed itself never runs -- and an unrun boundary is an unverified one."
    elif ! cmp -s "$f" "$AGENTS_MIRROR/$base"; then
      drift "$AGENTS_MIRROR/$base" \
"agent \`$base\` differs between $AGENTS_SHIPPED and the $AGENTS_MIRROR mirror." \
"re-copy from the shipped file, which is the source of truth: cp $f $AGENTS_MIRROR/. These two must be byte-identical -- unlike the hook wiring there is no path difference to justify any divergence, so what devseed runs would otherwise stop matching what it ships."
    fi
  done

  for f in "$AGENTS_MIRROR"/*.md; do
    [ -e "$f" ] || continue
    base="${f##*/}"
    [ -f "$AGENTS_SHIPPED/$base" ] && continue
    drift "$f" \
"agent \`$base\` exists in the $AGENTS_MIRROR mirror but not in $AGENTS_SHIPPED." \
"delete it, or move it into $AGENTS_SHIPPED so it ships. An agent devseed runs but does not ship is a boundary its consumers do not get, tested only here."
  done
}

# The skills are mirrored for the third time on the same reasoning as the hook
# wiring and the agent roster: an installed plugin pins to a commit SHA and goes
# stale, so devseed cannot dogfood a skill it only ships. Local-path install was
# tested rather than assumed and does not retire this -- it copies to a
# SHA-keyed cache exactly as a GitHub source does. See ADR-0016.
#
# Byte equality, as for the agents: a skill body carries no path difference
# between the two locations, so any difference at all is drift. Skills nest one
# directory deeper than agents, so the comparison walks the tree rather than
# globbing one level.
#
# Self-disabling in the same way: a consumer has no plugins/governed-dev/skills/
# and so is not checked.
SKILLS_SHIPPED="${DRIFT_SKILLS_SHIPPED:-plugins/governed-dev/skills}"
SKILLS_MIRROR="${DRIFT_SKILLS_MIRROR:-.claude/skills}"

check_skill_parity() {
  [ -d "$SKILLS_SHIPPED" ] || return 0
  [ -d "$SKILLS_MIRROR" ] || return 0

  local f rel
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$SKILLS_SHIPPED"/}"
    if [ ! -f "$SKILLS_MIRROR/$rel" ]; then
      drift "$SKILLS_MIRROR/$rel" \
"skill file \`$rel\` ships in $SKILLS_SHIPPED but is missing from the $SKILLS_MIRROR mirror." \
"copy it: cp $f $SKILLS_MIRROR/$rel. devseed loads its skills from the mirror, so a skill that exists only in the plugin is one devseed itself never runs -- and an unrun skill is an unverified one."
    elif ! cmp -s "$f" "$SKILLS_MIRROR/$rel"; then
      drift "$SKILLS_MIRROR/$rel" \
"skill file \`$rel\` differs between $SKILLS_SHIPPED and the $SKILLS_MIRROR mirror." \
"re-copy from the shipped file, which is the source of truth: cp $f $SKILLS_MIRROR/$rel. These two must be byte-identical -- unlike the hook wiring there is no path difference to justify any divergence, so what devseed runs would otherwise stop matching what it ships."
    fi
  done <<EOF
$(find "$SKILLS_SHIPPED" -type f 2>/dev/null | sort)
EOF

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$SKILLS_MIRROR"/}"
    [ -f "$SKILLS_SHIPPED/$rel" ] && continue
    drift "$f" \
"skill file \`$rel\` exists in the $SKILLS_MIRROR mirror but not in $SKILLS_SHIPPED." \
"delete it, or move it into $SKILLS_SHIPPED so it ships. A skill devseed runs but does not ship is a procedure its consumers do not get, tested only here."
  done <<EOF
$(find "$SKILLS_MIRROR" -type f 2>/dev/null | sort)
EOF
}

# ---------------------------------------------------------------------------

check_staleness
check_budget
check_orphans
check_superseded
check_adr_index
check_hook_parity
check_agent_parity
check_skill_parity

if [ "$FOUND" -gt 0 ]; then
  printf '\nGATE FAIL [%s]: %d drift finding(s) above. The documents and the repository disagree.\n' \
    "$CHECK" "$FOUND" >&2
  printf 'Each finding names a file, a line where one applies, and the fix. Resolve them rather than\n' >&2
  printf 'reconciling by hand in one direction -- see .claude/rules/precedence.md.\n' >&2
  exit 2
fi

note "check 7 (drift): documents and repository agree."
exit 0
