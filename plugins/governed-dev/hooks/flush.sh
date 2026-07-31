#!/usr/bin/env bash
#
# flush.sh -- PreCompact. Writes the session's in-flight state to
# .claude/in-flight.md before compaction discards the context that holds it.
#
# Compaction is the most common cause of working-memory drift: the session
# survives, the knowledge of what it was halfway through does not, and the
# post-compaction agent reconstructs a plausible substitute. orient.sh reads
# this file back and flags it, so a compacted session resumes from a record
# instead of from a reconstruction.
#
# WHY NOT CLAUDE.md. Appending here would defeat gate check 4, which fails a
# change when files under src/ moved and CLAUDE.md did not. A hook that touches
# CLAUDE.md on every compaction satisfies that check mechanically, forever,
# without anyone having thought about what changed -- turning the working-memory
# check into a no-op while it still reports green. It would also blow CLAUDE.md's
# 300-line ceiling with machine-written text, which the compression protocol
# exists to keep out. See ADR-0009.
#
# ALWAYS EXITS 0. Exit 2 at PreCompact blocks compaction, which would strand a
# session at a full context window -- a far worse outcome than a missing note.
HOOK_NAME="PreCompact/flush"
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(hook_root)"
[ -d "$ROOT/.claude" ] || mkdir -p "$ROOT/.claude" 2>/dev/null || exit 0
OUT="$ROOT/.claude/in-flight.md"

if have_jq; then
  TRIGGER="$(hook_field '.trigger')"
  SESSION="$(hook_field '.session_id')"
else
  TRIGGER="unknown"; SESSION="unknown"
  hook_note "jq missing; snapshot written without session details."
fi

STATE="$(hook_state_dir)"
SLUG="$(hook_session_slug)"
GATE_RESULT="not run this session"
[ -f "$STATE/last-gate-$SLUG" ] && GATE_RESULT="$(cat "$STATE/last-gate-$SLUG" 2>/dev/null)"

BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
HEAD_NOW="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)"
CHANGED="$(hook_changed_files)"

COMMITS=""
if [ -f "$STATE/head-$SLUG" ]; then
  COMMITS="$(git -C "$ROOT" log --format='%h %s' \
    "$(cat "$STATE/head-$SLUG" 2>/dev/null)..HEAD" 2>/dev/null)"
fi

TASK="$(awk '
  /^## T-[0-9]+/ { id=$2; title=$0; sub(/^## T-[0-9]+[^A-Za-z0-9]*/,"",title) }
  /^- \*\*Status:\*\* *in-progress/ { print id " — " title }
' "$ROOT/TASKS.md" 2>/dev/null | head -3)"

{
  printf '<!-- flush -->\n'
  printf '## In flight at %s (compaction: %s)\n\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)" "${TRIGGER:-unknown}"
  printf -- '- **Session:** %s\n' "${SESSION:-unknown}"
  printf -- '- **Branch:** %s at %s\n' "${BRANCH:-unknown}" "${HEAD_NOW:-unknown}"
  printf -- '- **Last gate result:** %s\n' "$GATE_RESULT"
  printf -- '- **Tasks marked in-progress:**\n'
  if [ -n "$TASK" ]; then printf '%s\n' "$TASK" | sed 's/^/    - /'
  else printf '    - (none — the ledger claims nothing is underway)\n'; fi
  printf -- '- **Uncommitted files:**\n'
  if [ -n "$CHANGED" ]; then printf '%s\n' "$CHANGED" | sed 's/^/    - /'
  else printf '    - (clean)\n'; fi
  printf -- '- **Commits made this session:**\n'
  if [ -n "$COMMITS" ]; then printf '%s\n' "$COMMITS" | sed 's/^/    - /'
  else printf '    - (none)\n'; fi
  printf '\n'
} >>"$OUT" 2>/dev/null || exit 0

# Keep only the four most recent snapshots. This file is a handoff note, not an
# audit trail -- .claude/activity.jsonl is the audit trail (ADR-0003), and two
# unbounded logs is one more than anyone reads.
_n="$(grep -c '^<!-- flush -->' "$OUT" 2>/dev/null)"
case "$_n" in ''|*[!0-9]*) _n=0 ;; esac   # grep -c exits 1 on zero matches; see orient.sh
if [ "$_n" -gt 4 ]; then
  awk 'BEGIN{RS="<!-- flush -->\n"} NR>1{a[++n]=$0}
       END{for(i=n-3;i<=n;i++) if(i>0) printf "<!-- flush -->\n%s", a[i]}' \
    "$OUT" >"$OUT.tmp" 2>/dev/null && mv "$OUT.tmp" "$OUT" 2>/dev/null
  rm -f "$OUT.tmp" 2>/dev/null
fi

hook_note "in-flight state written to .claude/in-flight.md before compaction."
exit 0
