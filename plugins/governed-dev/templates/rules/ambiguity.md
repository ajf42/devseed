# Rule: Ambiguity is not an invitation

When DESIGN.md is silent or ambiguous on something a change requires, **do not
invent.** Stop and flag the gap.

## Why this rule exists

The cost of asking is low — one question, one answer, a few minutes.

The cost of inventing a constraint the spec never sanctioned is high, because
within a week it becomes indistinguishable from a sanctioned one. Nothing in the
code marks it as a guess. It gets read, matched, and extended by the next change
and by the next reader. Later work is then built on a constraint no one ever
agreed to, and unwinding it means unwinding everything above it. An invented
constraint does not stay a local mistake; it compounds.

## What to do instead

Take one of these two paths. Not neither.

### 1. Ask the human

Preferred when the answer changes what gets built, or when proceeding under a
wrong assumption would make the work useless. Ask at the point the answer is
needed — do the work that does not depend on it first.

### 2. Record the gap in both places

When the work can proceed under a stated assumption, record it **twice**:

- A `TODO(spec): SG-NNNN — <what the spec omits>` marker **at the point of
  contact in the code** — the exact line or block where the unsanctioned
  decision was made. Name the assumption and that DESIGN.md does not cover it.
- An entry in **DECISIONS.md** under **"Spec gaps observed"**, headed
  `### SG-NNNN` — what was ambiguous, what was assumed, and what depends on it.

Both are required. The TODO alone is invisible to anyone reading the spec. The
DECISIONS.md entry alone is invisible to anyone reading the code. Together they
make the guess findable from either direction, which is the whole point: an
assumption that is labelled can be revisited, and an assumption that is not
becomes load-bearing by default.

The `SG-NNNN` id is the link between them, and the gate enforces it: a marker
citing no id, or citing one with no entry in DECISIONS.md, fails the build. Text
matching would be brittle; the id is not.

## Scope

This covers gaps in the *spec*, not gaps in your knowledge of the codebase. If
the answer is discoverable by reading the code, read the code. This rule is for
questions the code cannot answer because no one has decided yet.
