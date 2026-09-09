# ADR-0032 — The repository is public, as the position

- **Date:** 2026-09-09
- **Status:** Accepted

### Context

SG-0002 recorded `github.com/ajf42/devseed` as public "deliberately and
temporarily", on the understanding that private was required on
IP-entanglement grounds and that the window would close. The entry itself
named the defect in that: no end condition was ever recorded, and "temporary"
with no end condition decays into "public". T-011 sat blocked on it.

Shipping the plugin to other people is the end condition, arrived at from the
other direction. The documented install path —
`/plugin marketplace add ajf42/devseed` — clones over HTTPS unauthenticated,
which SG-0002 already recorded as the verified benefit of being public. The
consumer CI recipe (ADR-0035) clones by tag the same way. Both stop working
the day the repository goes private, for every consumer at once.

**Alternatives considered:**

- **Go private and ship to invited users.** Rejected: every consumer would
  need `gh auth` or a credential helper before the first install, every
  consumer CI job would need a secret, and the README's install section
  would describe a flow the author cannot test from a clean machine.
- **Leave the window open and ship anyway.** Rejected: that is the decay
  SG-0002 was rewritten to remove, taken deliberately this time.

### Decision

Public is the position, not a window. The IP-entanglement requirement is
withdrawn by the human on 2026-09-09. SG-0002 is resolved and T-011 is
dropped with this entry as the reason.

### Consequences

- Every push publishes. The repository must stay free of secrets and of
  third-party material the MIT licence (T-034) cannot cover. No check
  enforces this; it is a review habit, and it is named here so it is not
  mistaken for one.
- The install and CI paths can be exercised from any machine with no
  credential setup, which is what makes the end-to-end verification in the
  release checklist repeatable.
