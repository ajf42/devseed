# DECISIONS.md — {{PROJECT_NAME}}

Decision log. Append-only.

<!-- SKELETON. The Format and Conventions sections below are the mechanism —
     keep them. Add entries beneath. Delete this comment. -->

## Format

Every entry carries four parts, in this order:

- **Status** — `Accepted`, `Superseded by ADR-NNNN`, or `Rejected`.
- **Context** — the situation forcing a choice, and **the alternatives
  considered with why each was rejected**. An ADR that names only the option
  taken records a preference, not a decision; the rejected paths are what make
  it possible to tell later whether the reasoning still holds.
- **Decision** — what was chosen, stated so it can be checked against reality.
- **Consequences** — what follows, including the costs accepted. An entry with
  only upsides in this section is incomplete.

## Conventions

- **Newer entries append to the bottom.** Reading top to bottom is reading
  chronologically.
- **Superseded decisions are marked superseded, never deleted.** Set the old
  entry's Status to `Superseded by ADR-NNNN` and leave everything else intact.
  The superseding entry names what it replaces and why. History is not
  rewritten: a decision that was reversed is evidence about how this project
  reasons, and deleting it makes the reversal invisible to the next reader —
  who then has no way to know the ground has already been walked.
- **Numbering is permanent.** `ADR-0003` refers to the same thing forever, even
  once superseded. Numbers are never reused.
- Corrections to typos and links are fine in place. Corrections to *reasoning*
  are a new entry.

---

<!-- Template for a new entry; copy below and fill in.

## ADR-0001 — <short imperative title>

- **Date:** YYYY-MM-DD
- **Status:** Accepted

### Context

<what forced a choice>

**Alternatives considered:**

- **<option>.** Rejected: <why>.
- **<option>.** Rejected: <why>.

### Decision

<what was chosen>

### Consequences

<what follows, including costs accepted>

-->

---

## Spec gaps observed

Assumptions made where `DESIGN.md` was silent. Each is a guess until confirmed.

When a change requires something the spec does not cover, do not invent. Record
it in **both** places — a `TODO` at the point of contact in the code, and an
entry here. The TODO alone is invisible to anyone reading the spec; the entry
alone is invisible to anyone reading the code.

**Convention:** a gap that gets settled is marked `(resolved in <ref>)` in its
heading and its Status updated — it is **not** removed. The record of what was
once ambiguous is the useful part: it shows where the spec was thin, which is
where it is likely to be thin again.

<!-- Template for a gap; copy below and fill in.

### SG-0001 — <what the spec does not say>

- **Date:** YYYY-MM-DD
- **Status:** Open — needs human confirmation

**Assumed:** <the guess made, and why it was the least-committing option>

**Depends on this:** <what breaks or changes if the guess is wrong>

-->
