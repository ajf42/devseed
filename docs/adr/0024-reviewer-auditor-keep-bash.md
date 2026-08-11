# ADR-0024 — reviewer and auditor keep `Bash`; their write-boundary is best-effort by acceptance, not by accident

- **Date:** 2026-08-11
- **Status:** Accepted (human decision, 2026-08 audit closure)

### Context

The T-028 self-audit confirmed what ADR-0013 had already admitted: reviewer
and auditor hold `Bash` while `delegation.md`'s table said they "write
nothing," and the gap between those two statements is bridged only by the
syntactic `PreToolUse` hook, which stops the expedient redirect and not a
determined evasion. The audit filed it as a confirmed tension awaiting a
human ruling.

**Alternatives considered:**

- **Strip `Bash` from both agents.** Rejected: their job *is* running
  things — the reviewer runs tests, the gate, and `git diff`; the auditor
  runs the drift guards. Removing the shell cripples the function the
  agents exist for, leaving a boundary pure and a roster useless.
- **A stricter syntactic hook** (broader command patterns, deny-by-default
  on unrecognized shapes). Rejected: it raises the false-positive surface
  on exactly the two agents running the most varied commands — and a gate
  that cries wolf gets bypassed, which defeats the system more thoroughly
  than the narrow evasion it was meant to close.

### Decision

Reviewer and auditor keep `Bash`, permanently. The write-boundary for these
two agents is syntactic and best-effort — ADR-0013's existing admission,
now accepted as the design rather than tolerated as a gap. The backstop is
structural: their outputs are themselves gated. A reviewer or auditor that
somehow wrote its way past the hook still changes nothing durable without
passing the same gate, ledger checks, and drift guards as everything else.

`delegation.md`'s table (both the root copy and the shipped consumer copy)
now says what is true — "holds `Bash`; write-boundary best-effort, outputs
gated" — prose catching up to reality, per §5's own sanction.

### Consequences

- The audit's confirmed-tension item is closed. Future audits should cite
  this ADR rather than re-reporting the tension as a finding.
- The system accepts that its two watchdog agents are held by convention
  plus a syntactic net rather than by capability absence. Anyone extending
  the roster should copy the *pattern* knowingly: agents whose function
  needs a shell get one, and their outputs get gated instead.
