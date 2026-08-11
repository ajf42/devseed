# ADR-0028 — Three removals from the subtraction audit; and the TMPDIR incident, corrected

- **Date:** 2026-08-11
- **Status:** Accepted — human decision, given explicitly and marked final in
  the session of 2026-08-11 ("All three removals: REMOVE… Answers are final —
  implement them, don't re-litigate"), with per-item reasoning quoted below.
  Note on §6 step 2: the human approved the *decisions and their reasons*
  before this ADR existed, and forbade a further round trip. This entry
  records what was approved rather than seeking approval of itself.

### Context

ADR-0027 inventoried every enforcement mechanism and sent three to the human.
All three come back **remove**. This entry records what was removed, what each
was watching for, and what is now unguarded.

**On the evidence bar.** §6 demands "the specific incident that showed it
wrong… the rule *failed to catch what it existed to catch*, or *caught things
it should not have*." Two of these removals rest on an **absence** of
incidents, which that clause does not cover. They are sanctioned by a
different clause of the same section — §6's quarterly self-audit, which names
as its own question:

> **rules that have never fired**. A rule that never fires is either perfect
> or dead, and the audit's job is to determine which: a perfect rule's failure
> mode is found in the activity log as attempts it deflected; a dead rule
> deflects nothing because nothing reaches it, and a dead rule kept on the
> books teaches readers that rules here are decorative.

T-038/ADR-0027 is that audit, run early. It found no deflections for either
mechanism, so §6's own test returns *dead* rather than *perfect*. Recorded
because the route matters: these are not amendments made in spite of the
evidence bar, they are the subtraction §6 already provides for.

### What was removed, and what each was watching for

**1. `check_duplication` — drift.sh's duplication sub-check (~90 lines).**

It watched for `CLAUDE.md` copying a run of **12 or more contiguous words**
(`DRIFT_WINDOW`, default 12) out of any `DESIGN.md` section whose heading
names rules, conventions, constraints, a contract or standards. It normalised
both files first — Markdown links reduced to their label text, everything
non-alphanumeric folded to a separator, so smart quotes, em dashes, backticks
and list bullets could not disguise a copy — indexed the spec's token stream,
tested each window against a flattened `CLAUDE.md`, coalesced overlapping hits
into the largest contiguous span, and reported the `CLAUDE.md` line number
alongside the copied run. Its rationale (ADR-0012): a summary should reference
a rule, not restate it, because copied text is text that will silently diverge
from its source with no maintainer.

Removed because it never fired in real work across 27 ADRs, no incident in
the record is a copied-text defect, it is the largest single sub-check in the
largest component, and — by its own Known limit — it measured *copying*
rather than *agreement*, so a summary that was simply wrong always passed it.

**2. The deletion walk in `check_superseded`.**

It watched for an ADR or spec gap being deleted from `DECISIONS.md` rather
than marked superseded. Since a deleted entry leaves no trace in the file it
was deleted from, git history was the only witness: the walk read every
revision of `DECISIONS.md`, collected every `ADR-NNNN`/`SG-NNNN` heading that
ever existed, and required each to still be present.

Removed for the reason the human made decisive: **it is silently inert in a
shallow clone.** `actions/checkout` defaults to `fetch-depth: 1`, so in any
consumer CI using defaults the walk sees one revision, finds nothing to
compare, and passes — reading as coverage while providing none. This
repository's own CI ran that way until `8cd379f` (ADR-0025), and every
consumer inherits the default. Cost also grows with history: one
`git show <rev>:DECISIONS.md` per revision of the file.

**ADR-number contiguity is kept.** It retains the real protection — an ADR
number cannot silently vanish — at a fraction of the cost and with no
dependence on clone depth.

**3. `.github/workflows/audit.yml`.**

Removed. Verified against the GitHub API: six workflow runs exist in this
repository's entire history and all six are `gate`. It has never executed and
cannot, lacking an `ANTHROPIC_API_KEY` secret, and ADR-0021 still stands at
*Proposed — unverified in three specific ways*. A scheduled auditor that
cannot run is the failure this audit exists to find: it reads as continuous
verification and performs none. T-026 is reopened as unbuilt rather than
left looking done.

### The TMPDIR incident — correcting ADR-0027

**ADR-0027 states "No such incident is in the record." That is wrong, and
this entry corrects it.** The incident is real. Evidence, from the reflog and
a dangling object:

- Dangling commit `8782c53`, parent `f1ad979`, author `r <r@l>`, dated
  2026-08-11 13:46:00 −0400, subject `init`.
- Its diff: `CLAUDE.md` −251, `DECISIONS.md` −1856, `TASKS.md` −571 — 3
  insertions against 2,675 deletions. The three ledgers were replaced with
  `# CLAUDE.md`, `# TASKS.md`, and a three-line `# DECISIONS.md` carrying only
  a `## Spec gaps observed` heading: the exact fixture content
  `gate-regression.sh`'s `scaffold()` writes.
- Reflog: `f1ad979 HEAD@{2026-08-11 14:00:46}: reset: moving to f1ad979` —
  recovery by hard reset, fifteen minutes later, precisely as reported.
- `git branch -r --contains 8782c53` is empty: it never reached the remote.
  `DESIGN.md` and the rest of the tree were untouched.

The author signature is the tell. `gate-regression.sh` commits as
`regression <regression@local>` and `bootstrap-regression.sh` as `b <b@b>`;
**`r <r@l>` belongs to no sanctioned suite.** So the mechanism was an
improvised probe reproducing the scaffold's fixture strings while running in
the repository root instead of a scratch directory — which is exactly the
"improvised outside the sanctioned suites" characterisation, now evidenced.

**Why the earlier check missed it.** It searched the committed history of the
ledger files and the working tree. The truncation never entered committed
history *because it was reset away*; it survived only in the reflog and as a
dangling object, neither of which was examined. The conclusion drawn —
"no such incident is in the record" — was broader than the evidence
supported, and it was stated as settled fact rather than as the narrower
"nothing in main's committed history shows this."

That error is the same failure it was describing, one turn later and pointing
the other way: a self-report about the repository's correctness, asserted
without checking the part of the repository that would have falsified it. It
propagated no further only because the human asked for the reflog.

### Decision

`DESIGN.md` §5 changes, as exact replacement text.

Check-table row 7 — **before**:

> `CLAUDE.md` copies a run of a rules section, names a path that is gone,
> omits a directory that exists, or breaks its line budget; a cited
> `ADR-NNNN`/`SG-NNNN` has no entry; an ADR was deleted or its numbering has
> a hole; a done task's hash fails to resolve (re-checked here so standalone
> CI runs catch it); a mirrored hook wiring, agent, or skill differs from its
> shipped copy

**after**:

> `CLAUDE.md` names a path that is gone, omits a directory that exists, or
> breaks its line budget; a cited `ADR-NNNN`/`SG-NNNN` has no entry; ADR
> numbering has a hole; a done task's hash fails to resolve (re-checked here
> so standalone CI runs catch it); a mirrored hook wiring, agent, or skill
> differs from its shipped copy

Two supporting passages are deleted with the mechanisms they describe: the
"Conventions the gate depends on" bullet explaining that check 7 finds rules
sections by title, and the Known limit "Check 7 measures copying, not
agreement."

**Routes used, per §6's distinction.** The row-7 edit and those two deletions
are a **loosening** and went through `/amend` citing this ADR. The Known-limits
additions below are **corrections** — they document existing reality and
change no constraint — and went through the correction path.

### Consequences

- **Nothing now prevents `CLAUDE.md` from copying `DESIGN.md`'s rules text
  verbatim.** The divergence mechanism ADR-0012 identified is real and is now
  unguarded; only review catches it. Recorded in §5's Known limits.
- **ADR deletion is guarded only by contiguity.** Deleting `ADR-0019` is
  caught; deleting the highest-numbered ADR, or deleting one and renumbering
  the rest, is not. That is a narrower guarantee than the walk gave in a full
  clone, and a wider one than it gave in a shallow one.
- **T-026 is unbuilt again.** Headless verification is a real want; what
  existed was a file, not a capability.
- `drift.sh` drops from 672 lines to 555. Set against this entry's own cost
  in `DECISIONS.md`, the subtraction is a net loss of lines in scripts and a
  net gain in the ledger — which is the ledger-migration task's argument,
  not a counter-argument to removal.
