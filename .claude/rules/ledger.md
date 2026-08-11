# Rule: Which document owns which information

Five documents record what devseed is, why, and what is next. They do not
overlap. Before writing a fact down, decide which one owns it — guessing
produces the same fact in three places, drifting apart at three speeds.

## The routing question

Ask what *kind* of statement it is:

| The statement is… | It belongs in | Because |
|---|---|---|
| A constraint, an intent, something that **should be true** | `DESIGN.md` | Spec. Changes only via the amendment procedure (§6). |
| A description of what **is true right now** | `CLAUDE.md` | Current state. Expected to go stale; corrected in place. |
| **Why** a choice was made, and what was rejected | one file under `docs/adr/` | Rationale. Append-only; entries are superseded, never edited away. `DECISIONS.md` is the generated index over them (ADR-0029). |
| Work **not yet done** | `TASKS.md` | Backlog. One task per commit. |
| A record that **something happened** | `.claude/activity.jsonl` | Audit trail. Append-only, machine-written, never edited by hand. |

Two follow-up questions settle most of the remainder:

- **Would this still be true if all the code were deleted?** Yes → `DESIGN.md`.
  No → `CLAUDE.md`.
- **Is this a decision someone could reasonably have made differently?** Yes →
  it needs an ADR, whatever else it needs.

## The ADR lifecycle

One ADR is one file: `docs/adr/NNNN-short-slug.md`, numbered by taking the next
unused `NNNN`. **Numbering is permanent** — `ADR-0003` means the same thing
forever, numbers are never reused, and a citation of one resolves for the life
of the repository. Each entry carries Status, Context (**including the
alternatives rejected and why** — an entry naming only the option taken records
a preference, not a decision), Decision, and Consequences (**including the costs
accepted** — an entry with only upsides is incomplete).

**An ADR is active while its constraint is load-bearing.** Two things end that,
and both are a *move*, never a deletion:

- it is **superseded** — a later ADR replaces the constraint outright; or
- its **subject is deleted** — the thing it decided about no longer exists.

Either way it moves with `git mv` to `docs/adr/archive/`, and the index status
becomes `archived` on the next rebuild. **Archived is not gone.** A retired
entry still explains why the repository looks the way it does, so every
citation-resolving check searches `docs/adr/` **and** `docs/adr/archive/`. If
retiring an entry broke the citations pointing at it, retirement would be
destructive and nobody would do it — which is how a decision log fills with
entries no one dares touch.

A **partial** supersession is not a retirement: if any part of the entry is
still load-bearing it stays active, and the superseded part is named in its own
file and in the superseding one. `ADR-0001` is the worked example — its version
clause was replaced by `ADR-0026` while its plugin/governance split still
governs the repository's layout.

**The check that enforces this** (named here rather than left to memory, per
ADR-0023's discipline that a new rule arrives with its enforcement stated): the
**ADR index-parity check** in `gates/drift.sh`, which runs
`scripts/rebuild-adr-index.sh --print` and fails when the committed
`DECISIONS.md` differs from what the ADR files generate. Adding, renaming,
archiving, or re-statusing an entry without rebuilding the index is caught
there. What it does *not* check is whether an entry that should have been
archived actually was — "is this constraint still load-bearing?" is a judgement,
and no script makes it.

**The scribe owns the moves.** `docs/adr/` is in the scribe's writable set and
the implementer's denied set, for the same reason `DECISIONS.md` always was: an
agent that both makes a decision and records it can make the two agree by
editing whichever is cheaper.

**`DECISIONS.md` is generated.** Everything above the "Spec gaps observed"
heading comes from the ADR files; editing it changes nothing and is discarded
on the next rebuild. Regenerate with `bash scripts/rebuild-adr-index.sh`. The
gate never runs the generator — it is verification-only and writes nothing —
so rebuilding is the author's step, and forgetting it is what the parity check
reports.

## Boundaries that get blurred

**DESIGN.md vs. CLAUDE.md.** The most common error is recording an
implementation detail as spec, which silently promotes an accident into a
sanctioned constraint. If the code could change tomorrow without anyone
consenting to a spec change, it is state, not spec.

**CLAUDE.md vs. DECISIONS.md.** CLAUDE.md may state *that* something is so and
point at the ADR. It must not restate the reasoning — that is the ADR's job, and
a summary that drifts from its source is worse than a link.

**DECISIONS.md vs. TASKS.md.** A decision is closed; a task is open. "We will
use X" is an ADR. "Implement X" is a task. If it is genuinely undecided, it is
neither — it is a spec gap.

**Spec gaps.** When `DESIGN.md` is silent on something a change requires, the
answer is never to pick and move on. Record it in **both** places — a `TODO` at
the point of contact in the code, and an entry under "Spec gaps observed" in
`DECISIONS.md`. See [`ambiguity.md`](ambiguity.md).

## When a fact seems to belong in two places

It usually belongs in one, with a pointer from the other. Pick the owner by
which document would be *wrong* if the fact changed, and link from the rest.
Duplication is not redundancy here; it is three copies with one maintainer.

The exception is `CLAUDE.md`, which is allowed to carry one-line summaries of
things it does not own, because it is the entry point a fresh session reads
first. Summaries there stay short and always link to the owner.

## Overflow

`CLAUDE.md` has a hard line budget — target 200, ceiling 300. When a change
would exceed it, compress first, routing detail by the table above.
Per-directory `README.md` files are the correct home for local mechanics that
matter only inside one directory.

## Scope of this rule

This file governs **devseed itself**. A consumer-facing counterpart now ships:
`plugins/governed-dev/templates/rules/ledger.md`, which the bootstrap skill
installs into the consumer's `.claude/rules/`. The two say the same thing with
devseed's own ids and paths stripped from the shipped copy.

That is two copies with one maintainer, and no guard compares them — byte
equality would be wrong, since the difference is deliberate. When you edit this
file, check whether the shipped one needs the same change.
