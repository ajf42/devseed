#!/usr/bin/env bash
# Check 5 -- every task marked done carries a commit hash. Sourced by gate.sh.
CHECK="5/6 task ledger"

if [ ! -f TASKS.md ]; then
  note "check 5 (task ledger): no TASKS.md -- nothing to check."
else
  # A hash is a backticked hex string. 'pending' and '--' deliberately do not match.
  _bad="$(awk '
    function flush() { if (t != "" && d == 1 && h == 0) printf "  %s\n", t }
    # Only "## T-NNN" headings are tasks. Prose sections (Conventions, etc.)
    # mention "done" and would otherwise be flagged as hashless tasks.
    /^## /              { flush(); d = 0; h = 0; t = ""
                          if ($0 ~ /^## T-/) t = $0
                          next }
    /\*\*Status:\*\*/   { if ($0 ~ /done/) d = 1 }
    /\*\*Commit:\*\*/   { if ($0 ~ /`[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]/) h = 1 }
    END                 { flush() }
  ' TASKS.md)"

  [ -z "$_bad" ] || die \
"These TASKS.md entries are marked done but carry no commit hash:
$_bad
Record the hash of the commit that completed each one, or set the status back to in-progress. A task is not done until it points at the commit that did it -- otherwise the ledger claims work that nothing proves happened."

  unset _bad
fi
