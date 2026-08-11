# ADR-0023 — §6's shape: tightening fully exempt, `/amend` the chokepoint, bypass as two trailers

- **Date:** 2026-08-11
- **Status:** Accepted

### Context

Prompt 9 supplied §6's substance — ADR-before-edit with a named-incident
evidence bar, the tightening/loosening asymmetry, sanctioned emergency
bypass with reconciliation, the quarterly self-audit. Writing it into
DESIGN.md still forced choices the prompt did not make.

**Alternatives considered:**

- **Require a lightweight record even for tightenings** (a one-line log
  entry, short of an ADR). Rejected: the prompt's asymmetry is the design —
  "tightening a gate needs no ADR" — and a mistaken tightening is
  self-announcing (the gate blocks, someone notices, the fix carries its own
  incident). Ceremony on the safe direction prices safety.
- **Have `/amend` also handle emergency bypasses** — one tool for every
  gate-related exception. Rejected: a bypass is by definition done under
  pressure, outside procedure; wiring it into the procedural tool invites
  running the amendment machinery at the worst possible moment, and §6's
  trailer-plus-task obligations need no tool.
- **Have `/amend` commit its own amendment.** Rejected: `/task` is the only
  committer by design (Prompt 7), and an amendment commit is exactly the
  commit that most deserves the full loop.
- **Build the §6 enforcement checks now** (bypass reconciliation, CI-parity
  invocation guard, check-inventory parity). Rejected for this pass:
  T-028's findings become tasks (T-029, T-030) rather than unsanctioned
  same-commit mechanism — the audit's own discipline, applied to itself.

### Decision

§6 as written: correction vs. amendment defined by whether a constraint
changes; ADR → explicit human approval → edit, in that order, with `/amend`
the executor and sole sanctioned route; ratchet with tightening fully
exempt; bypass via `Gate-Bypassed:` / `Bypass-Reason:` trailers plus an
opened reconciliation task; quarterly self-audit with the first run dated
(T-028) and the next due 2026-11-11.

### Consequences

- §6's obligations are born unenforced — the bypass-reconciliation rule and
  the quarterly cadence hold by review until T-029 lands. Stated in §6
  itself rather than left to be discovered.
- `/amend` reads §6 at each run and defers to it, so an amendment to §6
  does not require re-editing the skill — but a §6 change that contradicts
  the skill's hard refusals (drift-to-spec, committing) would need the
  skill updated by ordinary means; the two are deliberately redundant on
  those two refusals.
- The chokepoint is honest but soft: nothing mechanical prevents a main-
  thread edit to DESIGN.md outside `/amend` (SG-0005's known scope limit).
  The procedure's authority rests on the same footing as the rest of the
  rule layer for main-thread work — convention plus review.
