# ADR-0022 — Commit trailer's `Agent-Type` is always `main`

- **Date:** 2026-08-11
- **Status:** Accepted

### Context

T-027 (closing SG-0010) asks every `/task`-made commit to carry a trailer
naming, among other fields, the agent type. But four agents genuinely
contribute to one task — spec-guardian, implementer, reviewer, scribe — and
none of them holds the tool that runs `git commit`; `/task` itself does, on
the main thread, which SG-0005 already notes carries no `agent_type` of its
own within this repository's boundary model.

**Alternatives considered:**

- **Attribute to whichever agent wrote the most lines**, e.g. `implementer`
  for ordinary tasks. Rejected: arbitrary (what counts as "most"?), and wrong
  for a task that is mostly a scribe or reviewer action.
- **List all four agents that ran**, e.g.
  `Agent-Type: spec-guardian,implementer,reviewer,scribe`. Rejected: true but
  low-signal — it would read the same on nearly every commit, telling a
  reader nothing they could not already assume from "this repo uses the
  four-agent loop."
- **`main`.** Chosen: it is simply the honest answer to "what made this git
  commit call" — matching `activity.sh`'s own existing default
  (`${AGENT:-main}`) for events with no subagent context — and it does not
  discard per-agent attribution, because `Session-Id` already joins the
  commit to every `SubagentStop` line in `.claude/activity.jsonl` for that
  session, each carrying its own real `agent_type`.

### Decision

Every `/task` commit trailer reads `Agent-Type: main`. Per-agent attribution
for a given task is recovered by joining `.claude/activity.jsonl` on the
commit's `Session-Id`, not by varying this field.

### Consequences

- The field is low-variance by design — expect to see `main` on every commit
  `/task` makes. Its value is ruling out *other* processes (a human commit, a
  future non-`/task` automation), not distinguishing among the four agents.
- This makes `.claude/activity.jsonl` load-bearing for the very question the
  trailer's introduction was meant to answer ("which agent wrote this"). If
  `activity.jsonl` is ever pruned or goes missing for a session, that
  session's commits keep their `Session-Id` but lose what it would have
  joined to.
