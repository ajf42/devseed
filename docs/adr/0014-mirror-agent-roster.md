# ADR-0014 — devseed mirrors the agent roster into `.claude/agents/`, and the guard enforces byte equality

- **Date:** 2026-08-05
- **Status:** Accepted

### Context

The roster is built under `plugins/governed-dev/agents/` per ADR-0001's path
rule, so it ships. But Claude Code discovers project subagents in
`.claude/agents/`, and reaches a plugin's agents only through an *installed*
plugin — which, per ADR-0011, is pinned to a commit SHA and stale by default.
The copy on this machine sits at `70542ef`, long before any agent existed.

So devseed could ship a roster it could never run. T-007's acceptance is an
**observed denial**, which cannot be observed against agents that do not load.
This is ADR-0011's problem exactly, one artifact later.

**Alternatives considered:**

- **Symlink `.claude/agents` at `plugins/governed-dev/agents`.** Rejected: one
  copy and no drift, which is the appealing part, but git symlinks on Windows
  require `core.symlinks` and developer mode or admin rights, and check out as
  plain text files containing a path when they are unavailable. That failure is
  silent — the roster would simply not load, which is the same invisible
  non-enforcement this ADR exists to prevent.
- **Install the plugin from a local path so the agents load from it.**
  Rejected for the reason ADR-0011 gives: it was not reachable from the
  documented `marketplace add` / `install` flow, and inventing an install mode
  to suit one repository is a larger change than a copy.
- **Skip the live test and rely on the synthetic harness.**
  `scripts/boundary-regression.sh` already proves the hook's logic across 73
  cases without an agent running. Rejected as *sufficient*: it proves
  `boundary.sh` decides correctly given an event, not that the harness delivers
  the event — the matcher, the `agent_type` field, and the plugin namespacing
  are all untested by it. T-005 found three defects of exactly that kind, none
  visible to inspection.
- **Copy without a guard.** Rejected: an unguarded copy is the drift devseed
  exists to eliminate, and it would diverge the first time an agent was edited
  in one place.

### Decision

Mirror the five agent files into `.claude/agents/`, and extend the drift guard's
check 6 to compare the two directories. The test is **exact byte equality** in
both directions: every shipped agent present in the mirror and identical, and no
agent in the mirror that does not ship.

Byte equality, rather than the field-level comparison used for the hook wiring,
because these files carry no legitimate difference. The hook mirror compares
only events, matchers and flags precisely because its command paths *must*
differ; agent definitions have no such axis, so any difference at all is drift.

### Consequences

- **`plugins/governed-dev/agents/` is the source of truth.** Edit there, then
  re-copy. Editing the mirror and letting the guard complain also works, but
  gets the direction backwards and the fix text says so.
- **Two more copies of five files exist in the repository.** Accepted because
  the guard makes the duplication self-correcting: it fails the gate rather
  than drifting quietly, which is the standard this repository holds every other
  duplication to.
- **A consumer is unaffected.** The check is self-disabling — no
  `plugins/governed-dev/agents/` means nothing to compare — and consumers get
  the roster through the plugin, which is the path that works for them.
- **This is the second artifact to need the ADR-0011 workaround**, after the
  hook wiring. A third would be evidence the pinned-install problem needs
  solving at its root rather than mirrored again per artifact.
