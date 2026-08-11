# ADR-0017 — The rule files ship to consumer projects

- **Date:** 2026-08-06
- **Status:** Accepted

*This resolves SG-0007.*

### Context

The five shipped agents cite `.claude/rules/precedence.md` and
`.claude/rules/ambiguity.md` by path, and `hooks/boundary.sh` cites
`.claude/rules/ambiguity.md` in its deny messages, but `.claude/rules/` did
not ship — so in a consumer project those references dangled while still
reading as authoritative. SG-0007 named three options and said T-008 forces
the answer. The human directed that one be picked and recorded, and that
leaving it undecided was the one thing not permitted.

**Alternatives considered:**

- **Inline each rule's substance into the agent prompts and drop the
  citations.** Rejected: it duplicates text into five files that will drift,
  which is exactly what drift check 1 exists to catch, and the rules are
  longer than an agent prompt should carry.
- **Ship the roster and document the dangling references in the plugin
  README.** Rejected: a reference that reads as authoritative and resolves to
  nothing is the worst of the three, and a README note does not reach the
  agent at the moment it cites the path.
- **Ship the rules.** Chosen.

### Decision

`plugins/governed-dev/templates/rules/` now holds consumer-facing
`precedence.md`, `ambiguity.md`, `delegation.md` and `ledger.md`, and the
bootstrap skill installs them into the consumer's `.claude/rules/`. The
shipped copies are the same substance with devseed's own ADR/SG ids and
repo-specific paths stripped.

### Consequences

- Consumers adopt more.
- Two copies of each rule now exist with one maintainer and **no guard
  compares them**, because byte equality would be wrong — the difference is
  deliberate (see SG-0011).
- `.claude/rules/ledger.md` said the shipping question was undecided and has
  been corrected in place.
- **Related defect surfaced:** nothing shipped from `templates/` may cite a
  devseed ADR/SG id, because the drift guard scans every tracked file and
  such a citation fails the *consumer's* gate on their first commit in a repo
  they have not touched. `templates/gate.sh`, `templates/.gitignore` and
  `templates/README.md` were rewritten to remove four such citations, and
  `scripts/bootstrap-regression.sh` now enforces the rule.
