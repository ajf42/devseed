# Rule: Which document owns which information

Five documents record what this project is, why, and what is next. They do not
overlap. Before writing a fact down, decide which one owns it — guessing
produces the same fact in three places, drifting apart at three speeds.

## The routing question

Ask what *kind* of statement it is:

| The statement is… | It belongs in | Because |
|---|---|---|
| A constraint, an intent, something that **should be true** | `DESIGN.md` | Spec. Changes only via the amendment procedure in §6. |
| A description of what **is true right now** | `CLAUDE.md` | Current state. Expected to go stale; corrected in place. |
| **Why** a choice was made, and what was rejected | `DECISIONS.md` | Rationale. Append-only; entries are superseded, never edited away. |
| Work **not yet done** | `TASKS.md` | Backlog. One task per commit. |
| A record that **something happened** | `.claude/activity.jsonl` | Audit trail. Append-only, machine-written, never edited by hand. |

Two follow-up questions settle most of the remainder:

- **Would this still be true if all the code were deleted?** Yes → `DESIGN.md`.
  No → `CLAUDE.md`.
- **Is this a decision someone could reasonably have made differently?** Yes →
  it needs an ADR in `DECISIONS.md`, whatever else it needs.

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
answer is never to pick and move on. Record it in **both** places — a
`TODO(spec): SG-NNNN` marker at the point of contact in the code, and an entry
under "Spec gaps observed" in `DECISIONS.md`. See [`ambiguity.md`](ambiguity.md).

## When a fact seems to belong in two places

It usually belongs in one, with a pointer from the other. Pick the owner by
which document would be *wrong* if the fact changed, and link from the rest.
Duplication is not redundancy here; it is three copies with one maintainer.

The exception is `CLAUDE.md`, which is allowed to carry one-line summaries of
things it does not own, because it is the entry point a fresh session reads
first. Summaries there stay short and always link to the owner.

## Overflow

`CLAUDE.md` has a hard line budget — target 200, ceiling 300 — because it is
read in full every session, and every line spends context that belongs to the
task. When a change would exceed it, compress *first*, routing detail by the
table above. Per-directory `README.md` files are the correct home for local
mechanics that matter only inside one directory.

A `CLAUDE.md` that grows without bound stops being read carefully, and an unread
current-state record is worse than none: it looks authoritative while nobody
checks it.
