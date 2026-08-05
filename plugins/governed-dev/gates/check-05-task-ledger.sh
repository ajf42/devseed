#!/usr/bin/env bash
# Check 5 -- every task marked done carries a hash that resolves to a commit.
# Sourced by gate.sh.
CHECK="5/7 task ledger"

if [ ! -f TASKS.md ]; then
  note "check 5 (task ledger): no TASKS.md -- nothing to check."
else
  require_git

  # Emit "<heading>\t<hash>" for every done task. Only "## T-NNN" headings are
  # tasks; prose sections mention "done" and would otherwise be flagged.
  # A hash is 7+ hex characters in backticks -- 'pending' does not match.
  _rows="$(awk '
    function flush() { if (t != "" && d == 1) printf "%s\t%s\n", t, h }
    /^## /            { flush(); d = 0; h = ""; t = ""
                        if ($0 ~ /^## T-/) t = $0
                        next }
    /\*\*Status:\*\*/ { if ($0 ~ /done/) d = 1 }
    /\*\*Commit:\*\*/ { if (match($0, /`[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*`/))
                          h = substr($0, RSTART + 1, RLENGTH - 2) }
    END               { flush() }
  ' TASKS.md)"

  while IFS="$(printf '\t')" read -r _task _hash; do
    [ -n "${_task:-}" ] || continue

    [ -n "${_hash:-}" ] || die \
"$_task is marked done but carries no commit hash. Record the hash of the commit that completed it, or set the status back to in-progress. A task is not done until it points at the commit that did it."

    # Format is not existence. A fabricated but well-formed hash would otherwise
    # pass, and a ledger that accepts unresolvable hashes proves nothing.
    [ "$(git cat-file -t "$_hash" 2>/dev/null)" = "commit" ] || die \
"$_task cites commit $_hash, which does not resolve to a commit in this repository. Correct it to the real hash, or set the status back to in-progress. A hash that resolves to nothing is a claim with no evidence behind it."
  done <<EOF
$_rows
EOF

  unset _rows _task _hash
fi
