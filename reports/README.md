# reports/

Autopilot run reports, one per stop or run cap: `autopilot-YYYY-MM-DD.md`,
suffixed `-2`, `-3` when a day has more than one run. Written and committed by
`scripts/autopilot.sh`, which is the only thing that writes here.

**A report is a decision queue, not a log.** Its first section, when present,
is the disagreements that stopped the loop — what the documents say, what the
repository says, the delta, and the options. Read that section; the rest is
awareness. Reports are never overwritten for exactly this reason: an unread
queue that a later run replaced would be work silently dropped.

**Nothing here duplicates git.** Reports link commit hashes rather than
re-explaining diffs, and cite documents by name and section rather than by ADR
number — a report is committed into the repository it describes, and an id that
resolves somewhere else would fail this repository's own citation check.

Old reports are history and can be deleted freely once their decisions are
taken; git holds them either way.
