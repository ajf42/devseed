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

# One index row per ADR file. Reads the id and title from the H1 and the status
# from the Status line, so the file is the single source and this is a view.
row() {
  local f="$1" archived="$2" id title status line num
  id="$(sed -n 's/^# \(ADR-[0-9]\{4\}\).*/\1/p' "$f" | head -1)"
  if [ -z "$id" ]; then
    printf 'MALFORMED\t%s\tno "# ADR-NNNN" heading\n' "$f"
    return
  fi
  title="$(sed -n "s/^# ADR-[0-9]\{4\}[[:space:]]*—[[:space:]]*//p" "$f" | head -1)"
  line="$(sed -n 's/^- \*\*Status:\*\*[[:space:]]*//p' "$f" | head -1)"

  if [ "$archived" = 1 ]; then
    status="archived"
  elif printf '%s' "$line" | grep -qi 'superseded in part'; then
    status="active"
  elif printf '%s' "$line" | grep -qiE 'superseded by \[?ADR-[0-9]{4}'; then
    num="$(printf '%s' "$line" | grep -oiE 'superseded by \[?ADR-[0-9]{4}' | grep -oE '[0-9]{4}' | head -1)"
    status="superseded-by-$num"
  else
    status="active"
  fi

  printf '%s\t%s\t%s\n' "$id" "$status" "$title"
}

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

  {
    for f in "$ADR_DIR"/*.md; do [ -e "$f" ] && row "$f" 0; done
    for f in "$ARCHIVE_DIR"/*.md; do [ -e "$f" ] && row "$f" 1; done
  } | sort | while IFS="$(printf '\t')" read -r id status title; do
    if [ "$id" = "MALFORMED" ]; then
      printf 'MALFORMED ADR file: %s (%s)\n' "$status" "$title" >&2
      exit 2
    fi
    # Link to wherever the file actually is.
    local_path="$(ls "$ADR_DIR"/"${id#ADR-}"-*.md 2>/dev/null | head -1)"
    [ -n "$local_path" ] || local_path="$(ls "$ARCHIVE_DIR"/"${id#ADR-}"-*.md 2>/dev/null | head -1)"
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
