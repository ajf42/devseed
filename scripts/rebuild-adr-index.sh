#!/usr/bin/env bash
#
# rebuild-adr-index.sh -- regenerate DECISIONS.md from docs/adr/.
#
# DECISIONS.md is an INDEX, not the record. Each ADR is its own file under
# docs/adr/ (or docs/adr/archive/ once retired), and this script reduces them
# to one line each: id, status, title. See ADR-0029.
#
# The "Spec gaps observed" section is NOT generated. It is hand-written and
# stays inline, deliberately: gaps are meant to be one short uncomfortable
# visible list, and a generated file nobody edits is a list nobody feels. This
# script preserves that section byte for byte from the existing DECISIONS.md.
#
# THE GATE NEVER RUNS THIS. The gate is verification-only and writes nothing
# (DESIGN.md §5, asserted by scripts/gate-regression.sh and run in CI since
# T-030). drift.sh instead calls this script with --print, which writes
# nothing, and compares the result to the committed file.
#
# Usage:  bash scripts/rebuild-adr-index.sh            rewrite DECISIONS.md
#         bash scripts/rebuild-adr-index.sh --print    write index to stdout
#
# Status derivation, in this order -- documented because drift.sh depends on
# it via --print and .claude/rules/ledger.md states it as the lifecycle rule:
#   1. file lives under docs/adr/archive/            -> archived
#   2. Status line says "superseded in part"          -> active (the entry is
#      still load-bearing; the partial supersession is named in its own file)
#   3. Status line says "superseded by ADR-NNNN"      -> superseded-by-NNNN
#   4. otherwise                                       -> active
#
# Deliberately not `set -e`: this script controls its own exits.
set -uo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  printf 'rebuild-adr-index.sh requires bash. Run it as: bash %s\n' "$0" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || { printf 'cannot enter %s\n' "$ROOT" >&2; exit 2; }

ADR_DIR="docs/adr"
ARCHIVE_DIR="docs/adr/archive"
INDEX="DECISIONS.md"

PRINT_ONLY=0
case "${1:-}" in
  "")       ;;
  --print)  PRINT_ONLY=1 ;;
  *)        printf 'unknown argument "%s". Use --print or no argument.\n' "$1" >&2; exit 2 ;;
esac

[ -d "$ADR_DIR" ] || { printf '%s does not exist -- nothing to index.\n' "$ADR_DIR" >&2; exit 2; }

# A literal tab, computed once. `IFS="$(printf '\t')" read` as a loop prefix
# re-expands the substitution on EVERY iteration and forks a subshell per row;
# that was the single largest cost T-046 found in drift.sh (ADR-0031), and this
# file carried the same idiom in the row loop below.
_TAB="$(printf '\t')"

emit_index() {
  cat <<'HDR'
# DECISIONS.md — devseed

<!-- GENERATED FILE. Do not edit above the "Spec gaps observed" heading.
     Regenerate with: bash scripts/rebuild-adr-index.sh
     Each ADR is its own file under docs/adr/; this is only the index.
     Editing a row here changes nothing -- edit the ADR file it points at. -->

Index of architectural decisions for **devseed's own development**. The
entries live in [`docs/adr/`](docs/adr/); retired ones move to
[`docs/adr/archive/`](docs/adr/archive/) and keep resolving forever (ADR-0029).
Numbering is permanent and never reused. The format each entry follows, and the
lifecycle that moves it, are in
[`.claude/rules/ledger.md`](.claude/rules/ledger.md).

This is not the template that ships to consumer projects — that one lives at
[`plugins/governed-dev/templates/DECISIONS.md`](plugins/governed-dev/templates/DECISIONS.md)
and is a skeleton by design.

## Decisions

| id | status | title |
|---|---|---|
HDR

  # The file list, existence-checked because an unmatched glob stays literal and
  # awk would try to open it. Positional parameters rather than an array:
  # `"${arr[@]}"` on an EMPTY array under `set -u` is an error in bash 3.2,
  # which is what the macOS leg of the CI matrix runs, while `"$@"` is
  # special-cased and safe everywhere.
  set --
  for f in "$ADR_DIR"/*.md;     do [ -e "$f" ] && set -- "$@" "$f"; done
  for f in "$ARCHIVE_DIR"/*.md; do [ -e "$f" ] && set -- "$@" "$f"; done
  [ "$#" -gt 0 ] || return 0

  # ONE awk pass for every field of every ADR. This replaced three `sed | head`
  # pairs, two or three `grep`s and an `ls | head` PER FILE -- 10-14 spawns
  # each, around 390 across the thirty-one. `check_adr_index` runs this script
  # with --print to verify the committed index, so the generator's cost is the
  # check's cost, and the check was the largest single item left in the gate
  # after T-046 (ADR-0031).
  #
  # This changes how the derivation READS, not what it derives: the same four
  # rules in the header comment, in the same order, against the same lines.
  #
  # Written mawk-safe, and asserted so by scripts/gate-regression.sh. No
  # ENDFILE -- per-file state is keyed by FILENAME rather than reset between
  # files -- and no ERE interval expressions: on an awk without them `{4}`
  # never matches, so every ADR would read as malformed and the index would
  # come back empty rather than wrong, which is ADR-0025's latent defect
  # arriving for real.
  awk -v arcpfx="$ARCHIVE_DIR/" '
    {
      fn = FILENAME
      # `| head -1` meant the FIRST match wins and later ones are ignored. The
      # per-file guards are that, and they are also what makes ENDFILE
      # unnecessary.
      if (!(fn in gotid) && match($0, /^# ADR-[0-9][0-9][0-9][0-9]/)) {
        gotid[fn] = 1
        id[fn] = substr($0, 3, 8)
      }
      if (!(fn in gottitle) && match($0, /^# ADR-[0-9][0-9][0-9][0-9][[:space:]]*—[[:space:]]*/)) {
        gottitle[fn] = 1
        title[fn] = substr($0, RSTART + RLENGTH)
      }
      if (!(fn in gotstatus) && match($0, /^- \*\*Status:\*\*[[:space:]]*/)) {
        gotstatus[fn] = 1
        stat[fn] = substr($0, RSTART + RLENGTH)
      }
    }
    END {
      # The link target is resolved by NUMBER taken from the id, docs/adr/
      # before docs/adr/archive/, first match winning -- exactly what
      # `ls <dir>/<num>-*.md | head -1` with the archive fallback did. Built
      # from the whole argument list before any row is emitted, because the
      # file carrying an id need not be the file named after it.
      for (i = 1; i < ARGC; i++) {
        f = ARGV[i]; b = f; sub(/^.*\//, "", b)
        if (match(b, /^[0-9][0-9][0-9][0-9]-/)) {
          n = substr(b, 1, 4)
          if (index(f, arcpfx) == 1) { if (!(n in arcp)) arcp[n] = f }
          else if (!(n in adrp)) adrp[n] = f
        }
      }

      # ARGV rather than the files actually read: a file with no lines never
      # triggers a rule, and an empty ADR is malformed, not absent.
      for (i = 1; i < ARGC; i++) {
        f = ARGV[i]
        if (!(f in gotid)) {
          printf "MALFORMED\t%s\t-\tno \"# ADR-NNNN\" heading\n", f
          continue
        }

        line = ""
        if (f in gotstatus) line = stat[f]
        low = tolower(line)

        # The four status rules, in the order the header comment states them.
        if (index(f, arcpfx) == 1)                  st = "archived"
        else if (index(low, "superseded in part"))  st = "active"
        else if (match(low, /superseded by \[?adr-[0-9][0-9][0-9][0-9]/)) {
          m = substr(low, RSTART, RLENGTH)
          st = "superseded-by-" substr(m, length(m) - 3)
        }
        else                                        st = "active"

        num = substr(id[f], 5)
        p = ""
        if (num in adrp) p = adrp[num]
        else if (num in arcp) p = arcp[num]

        printf "%s\t%s\t%s\t%s\n", id[f], st, p, title[f]
      }
    }
  ' "$@" | sort | while IFS= read -r rec; do
    # Split in the shell rather than with `read`'s IFS. Tab is an IFS
    # *whitespace* character, so `IFS=<tab> read a b c d` collapses runs of
    # tabs and one empty field silently shifts every field after it -- which is
    # what an ADR heading with no title, or an id resolving to no file, would
    # produce. Parameter expansion splits positionally and costs no process.
    id="${rec%%"$_TAB"*}";         rec="${rec#*"$_TAB"}"
    status="${rec%%"$_TAB"*}";     rec="${rec#*"$_TAB"}"
    local_path="${rec%%"$_TAB"*}"
    title="${rec#*"$_TAB"}"

    if [ "$id" = "MALFORMED" ]; then
      printf 'MALFORMED ADR file: %s (%s)\n' "$status" "$title" >&2
      exit 2
    fi
    printf '| [%s](%s) | %s | %s |\n' "$id" "$local_path" "$status" "$title"
  done
}

# The hand-written half, preserved exactly. If it is ever missing, stop rather
# than silently emit a DECISIONS.md with no spec gaps in it -- that would read
# as "no open gaps", which is a claim, not an absence.
spec_gaps() {
  if [ ! -f "$INDEX" ] || ! grep -q '^## Spec gaps observed' "$INDEX"; then
    printf 'refusing to generate: %s has no "## Spec gaps observed" section to preserve.\n' "$INDEX" >&2
    exit 2
  fi
  printf '\n'
  sed -n '/^## Spec gaps observed/,$p' "$INDEX"
}

OUT="$(emit_index)" || exit 2
GAPS="$(spec_gaps)" || exit 2

# CR stripped from the preserved half. `.gitattributes` pins only *.sh to LF
# (SG-0009), so on Windows this file checks out CRLF while the generated header
# above is written LF -- mixing them would make the parity check fail every
# Windows checkout, which is a false positive on a correct tree and the exact
# cross-platform class ADR-0025 came from. Line endings are a checkout artifact,
# not content.
GAPS="$(printf '%s' "$GAPS" | tr -d '\r')"

if [ "$PRINT_ONLY" = 1 ]; then
  printf '%s\n%s\n' "$OUT" "$GAPS"
  exit 0
fi

printf '%s\n%s\n' "$OUT" "$GAPS" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"
printf 'rebuilt %s from %s (%s active, %s archived)\n' \
  "$INDEX" "$ADR_DIR" \
  "$(ls "$ADR_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')" \
  "$(ls "$ARCHIVE_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')" >&2
exit 0
