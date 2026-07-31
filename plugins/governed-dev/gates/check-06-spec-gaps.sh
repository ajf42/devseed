#!/usr/bin/env bash
# Check 6 -- spec-gap markers in changed files are answered in DECISIONS.md.
# Sourced by gate.sh.
CHECK="6/6 spec gaps"
require_git

# The marker is assembled at runtime so this file does not flag itself.
_m="TODO"; _m="${_m}(spec)"

# Markdown is skipped: markers belong at the point of contact in code, and the
# documents that DEFINE the convention (DESIGN.md, DECISIONS.md) would otherwise
# match it. A marker parked in prose is not caught -- a known limit, see §5.
while IFS= read -r _f; do
  [ -n "$_f" ] && [ -f "$_f" ] || continue
  case "$_f" in *.md) continue ;; esac

  _found="$(grep -n -- "$_m" "$_f" 2>/dev/null)" || continue
  while IFS= read -r _line; do
    [ -n "$_line" ] || continue
    _no="${_line%%:*}"
    _id="$(printf '%s' "$_line" | sed -n 's/.*\(SG-[0-9][0-9]*\).*/\1/p')"

    [ -n "$_id" ] || die \
"$_f:$_no has a ${_m} marker citing no spec-gap id. Write it as '${_m}: SG-NNNN -- <what the spec does not say>' and add a matching SG-NNNN entry under 'Spec gaps observed' in DECISIONS.md. A marker nobody can trace is indistinguishable from a decision that was made."

    [ -f DECISIONS.md ] || die \
"$_f:$_no cites $_id but $ROOT has no DECISIONS.md. Create it with a 'Spec gaps observed' section and record $_id there."

    grep -q -- "$_id" DECISIONS.md 2>/dev/null || die \
"$_f:$_no cites $_id but DECISIONS.md has no such entry. Add $_id under 'Spec gaps observed' describing what the spec does not say, the assumption made, and what depends on it. Then re-run the gate."
  done <<EOF
$_found
EOF
done <<EOF
$(changed_files)
EOF

unset _m _f _found _line _no _id
